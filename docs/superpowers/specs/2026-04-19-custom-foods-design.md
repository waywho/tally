# Custom Foods (User-Contributed) — Design Spec

## Goal

Allow users to create, edit, and delete their own custom foods. Custom foods appear in the creator's search results alongside OFF and USDA foods. Other users cannot see each other's custom foods.

## Architecture

Extend the existing `FoodsController` with `new`, `create`, `edit`, `update`, and `destroy` actions. Update `Food.search` and `FoodSearch` to scope user-created foods to the current user. A "Create your own" link on the search page provides the entry point.

## Controller Actions

Extend `FoodsController` (already has `index` for search):

- `new` — renders the create form
- `create` — saves food with `source: :user`, `creator: current_user`. On success, redirects to `/foods?q={food_name}`. On failure, re-renders form with errors.
- `edit` — renders edit form. Scoped to `current_user.created_foods` (returns 404 for non-creator).
- `update` — updates the food. Scoped to creator. On success, redirects to `/foods?q={food_name}`. On failure, re-renders form.
- `destroy` — destroys the food. Scoped to creator. Redirects to `/foods` with flash notice.

All actions require authentication (already set via `before_action :require_authentication`).

### Routes

Update from `resources :foods, only: [:index]` to:

```ruby
resources :foods, only: [:index, :new, :create, :edit, :update, :destroy]
```

## Form

`/foods/new` and `/foods/:id/edit` share the same form partial.

**Fields:**
- Name (text, required, max 255 chars)
- Brand (text, optional)
- Calories per 100g (number, required, >= 0)
- Protein per 100g (number, required, >= 0)
- Carbs per 100g (number, required, >= 0)
- Fat per 100g (number, required, >= 0)
- Fiber per 100g (number, optional, default 0, >= 0)
- Barcode (text, optional)
- Serving size in grams (number, optional)
- Serving label (text, optional, e.g., "1 cup")

All nutritional values are entered and stored per 100g. Form labels clearly indicate "per 100g."

## Search Visibility Scoping

### Food.search Update

Add a `user:` parameter to `Food.search`:

```ruby
Food.search(query, limit: 20, user: nil)
```

When a `user` is provided:
- Foods with `source: :off` or `source: :usda` are always included
- Foods with `source: :user` are only included if `creator_id == user.id`

When no user is provided (or `nil`), user-created foods are excluded from results.

### FoodSearch Service Update

Pass `current_user` through `FoodSearch.call(query, user:)` to `Food.search`. The service already has dependency injection for clients; adding `user:` follows the same pattern.

### FoodsController Update

Pass `current_user` when calling `FoodSearch.call` in the `index` action.

## Entry Point

At the bottom of the search results partial (`_results.html.haml`), add a "Can't find it? Create your own" link:

- Visible when the user has searched (query is 3+ chars)
- Links to `/foods/new?name={query}` so the name field is pre-filled
- Styled as secondary text with a link

## After Creation

Redirect to `foods_path(q: @food.name)` so the new food appears in search results immediately.

## Testing

### Controller Tests

- `GET /foods/new` renders the form when authenticated
- `GET /foods/new` redirects when not authenticated
- `POST /foods` creates a food with `source: :user` and `creator_id` set to current user
- `POST /foods` with invalid params (missing name) re-renders form with errors
- `GET /foods/:id/edit` renders edit form for the food's creator
- `GET /foods/:id/edit` returns 404 for a different user
- `PATCH /foods/:id` updates the food for the creator
- `PATCH /foods/:id` returns 404 for a different user
- `DELETE /foods/:id` destroys the food for the creator
- `DELETE /foods/:id` returns 404 for a different user

### Search Scoping Tests

- User sees their own custom foods in search results
- User does not see other users' custom foods in search results
- OFF and USDA foods are visible to all users regardless

### Food.search Scope Tests

- With `user:` parameter, includes that user's custom foods
- With `user:` parameter, excludes other users' custom foods
- Without `user:` parameter, excludes all user-created foods
- Non-user-created foods are always included

## Out of Scope

- "Share to community" toggle (deferred to v2)
- Per-serving input with conversion (per 100g input only for MVP)
- Food detail/show page
- Image upload for custom foods
- Nutrition label scanning
