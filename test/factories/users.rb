FactoryBot.define do
  factory :user do
    account
    display_name { "Test User" }
    daily_calorie_target { 2000 }
    protein_target { 50 }
    carbs_target { 250 }
    fat_target { 65 }
    fiber_target { 30 }
    timezone { "UTC" }
    unit_preference { :metric }
    language { "en" }
    country { nil }
  end
end
