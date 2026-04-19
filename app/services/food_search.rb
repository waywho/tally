class FoodSearch
  LOCAL_THRESHOLD = 5

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

    local_results = Food.search(@query, limit: @limit, user: @user)

    if local_results.size >= LOCAL_THRESHOLD
      return local_results.first(@limit)
    end

    external_results = fetch_external_results(local_results)
    merged = merge_results(local_results, external_results)
    merged.first(@limit)
  end

  private

  def off_client
    @off_client ||= @injected_off_client || Off::Client.new
  end

  def usda_client
    @usda_client ||= @injected_usda_client || Usda::Client.new
  end

  def fetch_external_results(local_results)
    results = []

    # OFF: persist immediately (aggressive caching)
    begin
      off_results = off_client.search(@query, page: 1, per_page: 20)
      off_results.each do |off_result|
        food = off_client.persist(off_result)
        results << food
      end
    rescue Off::Error => e
      Rails.logger.warn("OFF search failed: #{e.message}")
    end

    # USDA: return transient structs (persist on interaction)
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
        local_ids.include?(["usda", result.fdc_id])
      else
        false
      end
    end

    local_results + deduped_external
  end
end
