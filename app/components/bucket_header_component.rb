class BucketHeaderComponent < ViewComponent::Base
  def initialize(meal:, subtotal:, add_path:)
    @meal = meal
    @subtotal = subtotal
    @add_path = add_path
  end
end
