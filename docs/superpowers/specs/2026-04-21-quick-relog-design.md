# Quick Re-log — Design Spec

## Goal

Show a "Quick add" section on the search page (with meal context) displaying the user's most frequently and recently logged foods, enabling one-tap re-logging of common foods without searching.

## Architecture

A `QuickAddFoods` service queries FoodLogEntry history, groups by food, and ranks by frequency + recency. Results are meal-scoped first with global fallback. The section appears on the search page when meal context is present and the search query is empty. No new models needed — everything is derived from existing FoodLogEntry data.

## Quick Add Logic

### Service

`QuickAddFoods.call(user:, meal:, limit: 10)` — returns an array of `Food` records ordered by relevance.

### Ranking algorithm

1. Query the user's FoodLogEntries scoped to the current meal, group by `food_id`
2. Order by `COUNT(*) DESC, MAX(logged_on) DESC` (most frequent first, tie-break by most recent)
3. If fewer than `limit` results, backfill with global results (any meal), excluding duplicates
4. Return up to `limit` Food records

### Meal scoping with global fallback

```
meal_scoped = entries.where(meal: meal).group(:food_id)
  .select("food_id, COUNT(*) as log_count, MAX(logged_on) as last_logged")
  .order("log_count DESC, last_logged DESC")
  .limit(limit)

if meal_scoped.size < limit
  remaining = limit - meal_scoped.size
  exclude_ids = meal_scoped.map(&:food_id)
  global = entries.where.not(food_id: exclude_ids).group(:food_id)
    .select("food_id, COUNT(*) as log_count, MAX(logged_on) as last_logged")
    .order("log_count DESC, last_logged DESC")
    .limit(remaining)
  
  food_ids = meal_scoped.map(&:food_id) + global.map(&:food_id)
else
  food_ids = meal_scoped.map(&:food_id)
end

Food.where(id: food_ids).index_by(&:id).values_at(*food_ids)
```

## UI

### Location

On the search page with meal context (`/foods?meal=breakfast&date=...`), between the templates section and the Turbo Frame search results.

### Visibility rules

- Visible when: meal context present AND query is empty or < 3 characters AND user has logging history
- Hidden when: query >= 3 characters (search results replace it) OR no meal context OR no history

### Row layout

Each food in the Quick add section uses the same result row layout as search results (food name, source badge, calories, macro line). Clicking a food opens the bottom sheet for quantity input, same as a search result.

### Section header

"Quick add" with a subtle label.

## Controller changes

### FoodsController#index

When meal context is present and query is empty/short:
```ruby
@quick_add_foods = QuickAddFoods.call(user: current_user, meal: @meal) if @meal.present? && @query.length < 3
```

### View changes

In `app/views/foods/index.html.haml`, render the Quick add section when `@quick_add_foods` is present and not empty. Render each food using the same result row markup as `_results.html.haml` (or extract a shared partial).

## Testing

### QuickAddFoods Service Tests

- Returns foods ordered by frequency then recency
- Scopes to current meal first, fills with global
- Deduplicates between meal-scoped and global results
- Caps at limit (default 10)
- Returns empty array for user with no logging history
- Excludes foods the user has never logged

### Controller Integration Tests

- Search page with meal context and empty query shows Quick add section
- Search page with meal context and query >= 3 chars hides Quick add
- Search page without meal context does not show Quick add

## Out of Scope

- Personalized ranking algorithm (ML-based)
- Time-of-day weighting (breakfast foods in the morning)
- Separate Recent and Frequent tabs (merged into one smart list)
- Quick add on non-meal-context search page
