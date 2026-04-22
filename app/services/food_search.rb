class FoodSearch
  # When local cache has at least this many matches, skip the OFF external call
  # (OFF is persisted into the local DB, so repeat searches are already served).
  # USDA is not cached, so it runs on every search regardless.
  LOCAL_OFF_THRESHOLD = 5

  # Tiebreaker weight per source when match quality is roughly equal.
  # User-created foods > USDA (whole-food staples) > OFF (branded).
  SOURCE_PRIORITY = {
    "user" => 15,
    "usda" => 10,
    "off"  => 0
  }.freeze

  def self.call(query, limit: 20, user: nil, off_client: nil, usda_client: nil)
    new(query, limit: limit, user: user, off_client: off_client, usda_client: usda_client).call
  end

  def initialize(query, limit: 20, user: nil, off_client: nil, usda_client: nil)
    @query = query
    @limit = limit
    @user = user
    @injected_off_client = off_client
    @injected_usda_client = usda_client
  end

  def call
    return [] if @query.blank?

    local_results = Food.search(@query, limit: @limit, user: @user).to_a
    external_results = fetch_external_results(
      skip_off: local_results.size >= LOCAL_OFF_THRESHOLD
    )

    merged = merge_results(local_results, external_results)
    merged.sort_by { |item| -relevance_score(item) }.first(@limit)
  end

  private

  def off_client
    @off_client ||= @injected_off_client || Off::Client.new
  end

  def usda_client
    @usda_client ||= @injected_usda_client || Usda::Client.new
  end

  def fetch_external_results(skip_off: false)
    results = []

    unless skip_off
      begin
        off_results = off_client.search(@query, page: 1, per_page: 20)
        off_results.each do |off_result|
          # Can't dedupe without a unique identifier — skip anonymous OFF entries
          # rather than persisting multiple rows that look identical.
          next if off_result.barcode.blank?
          food = off_client.persist(off_result)
          results << food
        end
      rescue Off::Error => e
        Rails.logger.warn("OFF search failed: #{e.message}")
      end
    end

    begin
      usda_results = usda_client.search(@query, page: 1, per_page: 20)
      results.concat(usda_results)
    rescue Usda::Error => e
      Rails.logger.warn("USDA search failed: #{e.message}")
    end

    results
  end

  def merge_results(local_results, external_results)
    local_ids = local_results.map { |f| [f.source, f.external_id] }.to_set

    deduped_external = external_results.reject do |result|
      case result
      when Food
        local_ids.include?([result.source, result.external_id])
      when Usda::FoodResult
        local_ids.include?(["usda", result.fdc_id.to_s])
      else
        false
      end
    end

    local_results + deduped_external
  end

  # Unified relevance scorer across local Food records and transient Usda::FoodResult
  # structs. Produces a score where higher = more relevant. Combines:
  #   - Match quality (exact > prefix-with-word-boundary > prefix > word > substring)
  #   - Length penalty (shorter names win when match quality is tied)
  #   - Source tiebreaker (user > usda > off)
  def relevance_score(item)
    name = (item.name || "").downcase.strip
    q = @query.downcase.strip

    return 1000.0 if name == q

    base =
      if name.start_with?(q)
        next_char = name[q.length]
        # Full word boundary after the query (e.g. "apple," or "apple ") beats
        # continuation (e.g. "apples", "applesauce").
        (next_char.nil? || !next_char.match?(/[[:alnum:]]/)) ? 600 : 500
      elsif name.match?(/\b#{Regexp.escape(q)}\b/i)
        200
      elsif name.include?(q)
        50
      else
        0
      end

    # Cap the length penalty so very long names aren't crushed entirely — they
    # can still beat poor matches via their base score.
    length_penalty = [name.length, 40].min * 0.5
    priority = SOURCE_PRIORITY.fetch(item_source(item), 0)

    base - length_penalty + priority
  end

  def item_source(item)
    if item.respond_to?(:source) && item.source
      item.source.to_s
    else
      "usda"  # Usda::FoodResult doesn't carry a source field
    end
  end
end
