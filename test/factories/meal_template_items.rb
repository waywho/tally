FactoryBot.define do
  factory :meal_template_item do
    association :meal_template
    association :food
    weight { 150 }
  end
end
