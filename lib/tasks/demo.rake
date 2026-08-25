namespace :demo do
  desc "Seed the demo account used for App Store screenshots and App Review"
  task seed: :environment do
    abort "Refusing to run outside development" unless Rails.env.development?

    email = ENV.fetch("DEMO_EMAIL", "demo@tally.quest")
    account = Account.find_by(email: email)
    abort "No account for #{email}. Sign up through the UI first, then rerun." if account.nil?

    account.update!(status: "verified")
    user = account.user
    user.update!(
      display_name: "Alex",
      daily_calorie_target: 2000, protein_target: 130, carbs_target: 220,
      fat_target: 65, fiber_target: 30,
      timezone: "London", onboarded_at: Time.current
    )

    # Foods from the public databases, as a search would have created them.
    catalogue = {
      "Greek Yogurt, Plain" => [ "Fage", 97, 10.3, 3.6, 5.0, 0.0 ],
      "Blueberries" => [ nil, 57, 0.7, 14.5, 0.3, 2.4 ],
      "Porridge Oats" => [ "Quaker", 372, 11.0, 60.0, 8.0, 9.0 ],
      "Chicken Breast, Grilled" => [ nil, 165, 31.0, 0.0, 3.6, 0.0 ],
      "Brown Rice, Cooked" => [ nil, 123, 2.7, 25.6, 1.0, 1.6 ],
      "Avocado" => [ nil, 160, 2.0, 8.5, 14.7, 6.7 ],
      "Salmon Fillet, Baked" => [ nil, 208, 20.4, 0.0, 13.4, 0.0 ],
      "Sweet Potato, Roasted" => [ nil, 90, 2.0, 20.7, 0.2, 3.3 ],
      "Tenderstem Broccoli" => [ nil, 35, 3.7, 4.0, 0.4, 3.3 ],
      "Almonds" => [ nil, 579, 21.2, 21.6, 49.9, 12.5 ],
      "Dark Chocolate 70%" => [ "Lindt", 566, 9.0, 34.0, 41.0, 11.0 ],
      "Turkey Mince 5%" => [ nil, 148, 21.0, 0.0, 5.0, 0.0 ],
      "Kidney Beans, Tinned" => [ nil, 100, 6.7, 15.0, 0.5, 6.4 ],
      "Chopped Tomatoes" => [ nil, 22, 1.1, 4.0, 0.2, 1.1 ],
      "Red Onion" => [ nil, 42, 1.1, 9.3, 0.1, 1.7 ]
    }

    foods = catalogue.to_h do |name, (brand, calories, protein, carbs, fat, fiber)|
      food = Food.find_or_create_by!(name: name, brand: brand, creator_id: nil) do |f|
        f.calories = calories
        f.protein = protein
        f.carbs = carbs
        f.fat = fat
        f.fiber = fiber
        f.serving_size = 100
        f.serving_label = "100 g"
        f.source = :usda
      end
      [ name, food ]
    end

    # Foods the demo user entered themselves, so My Foods isn't empty.
    [
      [ "Mum's Banana Bread", nil, 326, 4.3, 54.0, 11.0, 2.1 ],
      [ "Protein Shake, Chocolate", "My Blend", 118, 22.0, 3.4, 1.9, 0.8 ],
      [ "Sourdough Loaf", "Corner Bakery", 251, 9.6, 48.0, 1.6, 2.4 ],
      [ "Overnight Oats, House Recipe", nil, 148, 6.2, 21.0, 4.4, 3.1 ]
    ].each do |name, brand, calories, protein, carbs, fat, fiber|
      Food.find_or_create_by!(name: name, brand: brand, creator_id: user.id) do |f|
        f.calories = calories
        f.protein = protein
        f.carbs = carbs
        f.fat = fat
        f.fiber = fiber
        f.serving_size = 100
        f.serving_label = "100 g"
        f.source = :user
      end
    end

    FoodLogEntry.where(user: user).destroy_all
    [
      [ "Greek Yogurt, Plain", :breakfast, 150 ],
      [ "Blueberries", :breakfast, 80 ],
      [ "Porridge Oats", :breakfast, 50 ],
      [ "Chicken Breast, Grilled", :lunch, 150 ],
      [ "Brown Rice, Cooked", :lunch, 200 ],
      [ "Avocado", :lunch, 50 ],
      [ "Salmon Fillet, Baked", :dinner, 140 ],
      [ "Sweet Potato, Roasted", :dinner, 200 ],
      [ "Tenderstem Broccoli", :dinner, 120 ],
      [ "Almonds", :snacks, 25 ],
      [ "Dark Chocolate 70%", :snacks, 20 ]
    ].each do |name, meal, weight|
      FoodLogEntry.create!(user: user, food: foods.fetch(name), logged_on: Date.current, meal: meal, weight: weight)
    end

    # A recipe is backed by a generated Food so it can be logged like anything
    # else; RecipesController#create builds that pair, and compute_nutrition!
    # fills in the per-100g figures.
    build_recipe = lambda do |name, servings, ingredients|
      backing = user.created_foods.create!(
        name: name, source: :user,
        calories: 0, protein: 0, carbs: 0, fat: 0, fiber: 0
      )
      recipe = Recipe.create!(user: user, name: name, servings_in_recipe: servings, food: backing)
      ingredients.each { |food_name, grams| RecipeIngredient.create!(recipe: recipe, food: foods.fetch(food_name), weight: grams) }
      recipe.compute_nutrition!
      recipe
    end

    Recipe.where(user: user).destroy_all
    build_recipe.call("Weeknight Turkey Chilli", 4,
      { "Turkey Mince 5%" => 500, "Kidney Beans, Tinned" => 400, "Chopped Tomatoes" => 400, "Red Onion" => 120 })
    build_recipe.call("Big Bowl Porridge", 2,
      { "Porridge Oats" => 100, "Blueberries" => 80, "Almonds" => 20 })

    MealTemplate.where(user: user).destroy_all
    breakfast = MealTemplate.create!(user: user, name: "Usual Breakfast")
    { "Greek Yogurt, Plain" => 150, "Blueberries" => 80, "Porridge Oats" => 50 }
      .each { |name, grams| MealTemplateItem.create!(meal_template: breakfast, food: foods.fetch(name), weight: grams) }

    puts "Demo account: #{email}"
    puts "  entries today: #{FoodLogEntry.where(user: user, logged_on: Date.current).count}"
    puts "  own foods:     #{Food.where(creator_id: user.id).count}"
    puts "  recipes:       #{Recipe.where(user: user).count}"
    puts "  templates:     #{MealTemplate.where(user: user).count}"
  end
end
