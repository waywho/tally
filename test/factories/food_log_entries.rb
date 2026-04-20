FactoryBot.define do
  factory :food_log_entry do
    user
    food
    logged_on { Date.current }
    meal { :breakfast }
    weight { 100.0 }
  end
end
