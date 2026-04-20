FactoryBot.define do
  factory :recipe_ingredient do
    association :recipe
    association :food
    weight { 150 }
  end
end
