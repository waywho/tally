FactoryBot.define do
  factory :food_log_entry do
    user
    food
    logged_on { Date.current }
    meal { :breakfast }
    quantity_g { 100.0 }
  end
end
