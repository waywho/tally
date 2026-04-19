class CaloriePillComponentPreview < Lookbook::Preview
  # @label Normal (470 / 2,000)
  def normal
    render CaloriePillComponent.new(
      eaten: 470, target: 2000,
      protein: "28g / 150g", carbs: "52g / 250g", fat: "12g / 67g", fiber: "8g / 30g"
    )
  end

  # @label Over target (2,150 / 2,000)
  def over_target
    render CaloriePillComponent.new(
      eaten: 2150, target: 2000,
      protein: "165g / 150g", carbs: "280g / 250g", fat: "72g / 67g", fiber: "35g / 30g"
    )
  end

  # @label Remaining variant (470 / 2,000)
  def remaining_variant
    render CaloriePillComponent.new(
      eaten: 470, target: 2000,
      protein: "28g / 150g", carbs: "52g / 250g", fat: "12g / 67g", fiber: "8g / 30g",
      variant: :remaining
    )
  end

  # @label Empty day
  def empty_day
    render CaloriePillComponent.new(
      eaten: 0, target: 2000,
      protein: "0g / 150g", carbs: "0g / 250g", fat: "0g / 67g", fiber: "0g / 30g"
    )
  end
end
