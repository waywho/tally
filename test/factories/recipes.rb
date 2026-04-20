FactoryBot.define do
  factory :recipe do
    association :user
    sequence(:name) { |n| "Recipe #{n}" }
    servings_in_recipe { 4 }

    after(:build) do |recipe|
      recipe.food ||= build(:food, :user_created, creator: recipe.user)
    end
  end
end
