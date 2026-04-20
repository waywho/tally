# Recipes — Design Spec

## Goal

Allow users to create recipes from existing foods, with computed per-100g nutrition stored as a generated Food record. Recipes can be logged like any other food — no special cases in the logging flow.

## Architecture

A Recipe is a builder for a Food. It has a name, a number of servings, and a list of ingredients (each referencing a Food + weight in grams). On save, the recipe computes total weight, per-100g nutrition, and creates/updates a linked Food record (`source: :user`). Logging a recipe means logging this generated Food — the logging flow stays completely uniform.

## Data Model

### Recipe

| Column | Type | Constraints |
|--------|------|-------------|
| `user_id` | references | required, FK to users, on_delete: cascade |
| `name` | string | required, max 255 |
| `servings_in_recipe` | decimal(8,2) | required, > 0 |
| `food_id` | references | required, FK to foods — the generated Food record |
| timestamps | | |

**Associations:**
- `belongs_to :user`
- `belongs_to :food` — the generated Food with computed nutrition
- `has_many :recipe_ingredients, dependent: :destroy`
- `accepts_nested_attributes_for :recipe_ingredients, allow_destroy: true`
- User `has_many :recipes, dependent: :destroy`

### RecipeIngredient

| Column | Type | Constraints |
|--------|------|-------------|
| `recipe_id` | references | required, FK to recipes, on_delete: cascade |
| `food_id` | references | required, FK to foods — the ingredient |
| `weight` | decimal(8,2) | required, > 0 — grams of this ingredient |
| timestamps | | |

**Associations:**
- `belongs_to :recipe`
- `belongs_to :food`

**Indexes:**
- `(recipe_id)` — list ingredients for a recipe
- `(food_id)` — find recipes using a specific food

## Nutrition Computation

On recipe save (create or update), compute and update the linked Food record:

1. `total_weight` = sum of all `recipe_ingredient.weight`
2. For each nutrient (calories, protein, carbs, fat, fiber):
   - `total_nutrient` = sum of `(ingredient.food.nutrient * ingredient.weight / 100)` for all ingredients
   - `per_100g` = `total_nutrient / total_weight * 100`
3. Update the linked Food with:
   - `name` = recipe name
   - `calories` = per-100g calories
   - `protein`, `carbs`, `fat`, `fiber` = per-100g values
   - `serving_size` = `total_weight / servings_in_recipe`
   - `serving_label` = "1 serving"
   - `source` = `:user`
   - `creator` = recipe owner

This computation runs automatically on every recipe save (auto-update, no manual publish step).

## Routes

```ruby
resources :recipes
```

## Controller

`RecipesController` — full CRUD:
- `index` — list current user's recipes
- `show` — recipe detail with ingredients and nutrition summary
- `new` / `create` — create recipe with ingredients, generate Food
- `edit` / `update` — modify recipe, recalculate Food
- `destroy` — delete recipe + its generated Food

All actions scoped to `current_user.recipes`.

## Views

### Index (`/recipes`)
- List of user's recipes with name and per-serving calories
- "Create Recipe" button

### New / Edit
- Recipe name field
- Servings count field
- Ingredients list:
  - Each ingredient: food search/select + weight (grams)
  - Add/remove ingredients dynamically (Stimulus controller)
- Computed nutrition preview (updates as ingredients change)

### Show
- Recipe name, servings count
- Ingredients list with per-ingredient nutrition
- Total and per-serving nutrition summary
- Edit / Delete buttons

## Ingredient Management

Use `accepts_nested_attributes_for :recipe_ingredients` with `allow_destroy: true`. A Stimulus controller handles adding/removing ingredient rows dynamically in the form.

Each ingredient row has:
- A food search/select field (can reuse existing food search, simplified)
- A weight field (grams)
- A remove button

For MVP, the food select can be a simple text input with autocomplete, or a dropdown populated from the user's food history. A simple `select` from existing foods in the DB is acceptable for MVP.

## Logging Flow

No changes to the logging system. The recipe's generated Food appears in search results (it's a regular `source: :user` food owned by the user). The `serving_size` is set to `total_weight / servings_in_recipe`, so the user can log by grams or know how much one serving weighs.

## Testing

### Recipe Model Tests
- Validates presence of name, servings_in_recipe, user
- Validates servings_in_recipe > 0
- Has many recipe_ingredients, dependent: destroy
- Belongs to user, belongs to food
- `compute_nutrition!` correctly calculates per-100g values
- `compute_nutrition!` updates the linked Food record
- `compute_nutrition!` sets serving_size = total_weight / servings_in_recipe

### RecipeIngredient Model Tests
- Validates presence of food, weight
- Validates weight > 0
- Belongs to recipe, belongs to food

### RecipesController Tests
- `GET /recipes` lists user's recipes (not other users')
- `GET /recipes/new` renders form
- `POST /recipes` creates recipe + ingredients + generated Food
- `POST /recipes` with invalid params re-renders form
- `GET /recipes/:id` shows recipe with ingredients
- `GET /recipes/:id/edit` renders edit form for owner
- `GET /recipes/:id/edit` returns 404 for non-owner
- `PATCH /recipes/:id` updates recipe, recalculates Food
- `DELETE /recipes/:id` destroys recipe + generated Food

## Out of Scope

- Recipe sharing / community recipes
- Recipe image upload
- Recipe categories or tags
- Importing recipes from URLs
- Scaling recipes (change servings count and auto-adjust ingredients)
- Inline food search within ingredient rows (use simple select for MVP)
