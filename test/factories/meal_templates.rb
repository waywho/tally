FactoryBot.define do
  factory :meal_template do
    association :user
    sequence(:name) { |n| "Template #{n}" }
  end
end
