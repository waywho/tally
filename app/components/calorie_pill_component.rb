class CaloriePillComponent < ViewComponent::Base
  VARIANTS = %i[consumed remaining].freeze

  def initialize(eaten:, target:, protein:, carbs:, fat:, fiber:, variant: :consumed)
    @eaten = eaten
    @target = target
    @protein = protein
    @carbs = carbs
    @fat = fat
    @fiber = fiber
    @variant = variant
  end

  def remaining_variant?
    @variant == :remaining
  end

  def remaining
    @target - @eaten
  end

  def over_target?
    @eaten > @target
  end

  def progress_percent
    return 100 if over_target?
    return 0 if @target.zero?
    eaten_pct = ((@eaten.to_f / @target) * 100).round
    remaining_variant? ? 100 - eaten_pct : eaten_pct
  end

  def formatted_eaten
    ActiveSupport::NumberHelper.number_to_delimited(@eaten)
  end

  def formatted_target
    ActiveSupport::NumberHelper.number_to_delimited(@target)
  end

  def formatted_remaining
    ActiveSupport::NumberHelper.number_to_delimited(remaining.abs)
  end
end
