class CaloriePillComponent < ViewComponent::Base
  def initialize(eaten:, target:, protein:, carbs:, fat:, fiber:)
    @eaten = eaten
    @target = target
    @protein = protein
    @carbs = carbs
    @fat = fat
    @fiber = fiber
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
    ((@eaten.to_f / @target) * 100).round
  end

  def formatted_target
    ActiveSupport::NumberHelper.number_to_delimited(@target)
  end

  def formatted_remaining
    ActiveSupport::NumberHelper.number_to_delimited(remaining.abs)
  end
end
