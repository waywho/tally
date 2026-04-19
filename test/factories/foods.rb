FactoryBot.define do
  factory :food do
    sequence(:name) { |n| "Food Item #{n}" }
    brand { "Generic Brand" }
    calories { 250.0 }
    protein { 10.0 }
    carbs { 30.0 }
    fat { 12.0 }
    fiber { 3.0 }
    source { :off }
    sequence(:external_id) { |n| "off-#{n}" }
    serving_size { 100.0 }
    serving_label { "1 serving" }

    trait :usda do
      source { :usda }
      sequence(:external_id) { |n| "usda-#{n}" }
      brand { nil }
    end

    trait :user_created do
      source { :user }
      external_id { nil }
      creator factory: :user
    end
  end
end
