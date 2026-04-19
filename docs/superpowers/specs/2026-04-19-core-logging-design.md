# Core Food Logging (Tickets 15-18) — Design Spec

## Goal

Build the core food logging loop: a FoodLogEntry model, a Today view with meal buckets showing daily nutrition progress, an add-food flow with bottom sheet quantity input and swipeable meal/daily tally, and edit/delete for entries.

## Architecture

`FoodLogEntry` stores what a user ate (food + grams + meal + date). Calories and macros are computed on read from the food's per-100g values. A `DaysController` renders the Today view grouped by meal buckets. The add-food flow reuses the existing search page with meal context, adding a bottom sheet for quantity input. A Stimulus controller handles the swipeable tally card and live calorie preview.

## Data Model

### FoodLogEntry

| Column | Type | Constraints |
|--------|------|-------------|
| `user_id` | references | required, FK to users, on_delete: cascade |
| `food_id` | references | required, FK to foods |
| `logged_on` | date | required |
| `meal` | integer | required, enum |
| `quantity_g` | decimal(8,2) | required, > 0 |
| timestamps | | |

**Enum:** `meal` — `{ breakfast: 0, lunch: 1, dinner: 2, snacks: 3 }`

**Associations:**
- `belongs_to :user`
- `belongs_to :food`
- User `has_many :food_log_entries, dependent: :destroy`

**Indexes:**
- `(user_id, logged_on)` — daily queries
- `(user_id, food_id)` — future "frequent foods" feature

**Computed methods** (not stored):
- `calories` → `food.calories * quantity_g / 100`
- `protein` → `food.protein * quantity_g / 100`
- `carbs` → `food.carbs * quantity_g / 100`
- `fat` → `food.fat * quantity_g / 100`
- `fiber` → `food.fiber * quantity_g / 100`

**Validations:**
- Presence: user, food, logged_on, meal, quantity_g
- quantity_g: numericality greater_than 0

## Routes

```ruby
get "today", to: "days#show", defaults: { date: nil }
resources :days, only: [:show], param: :date do
  resources :food_log_entries, only: [:create, :edit, :update, :destroy], path: "entries"
end
```

The `/today` route renders `DaysController#show` with today's date. `/days/2026-04-19` renders a specific day.

## Today View

### DaysController#show

Requires authentication. Loads all `FoodLogEntry` records for the current user and date, groups by meal. Computes per-bucket and daily totals.

**Instance variables:**
- `@date` — the date being viewed (Date object)
- `@entries_by_meal` — hash of meal → entries array
- `@meal_totals` — hash of meal → { calories, protein, carbs, fat, fiber }
- `@daily_totals` — { calories, protein, carbs, fat, fiber, target_calories, target_protein, target_carbs, target_fat, target_fiber }

### Layout

1. **Date header:** "Saturday, Apr 19" (static for now — date navigation is Ticket 19)
2. **Calorie summary card:** green-tinted background
   - Large consumed/target calories (e.g., "1,240 / 2,000 kcal")
   - Progress bar
   - Macro row: Protein · Carbs · Fat · Fiber (consumed / target)
3. **Meal buckets** (Breakfast, Lunch, Dinner, Snacks), each:
   - Header: meal name + bucket calorie subtotal
   - Entry rows: food name + (quantity_g) + computed calories
   - "+ Add food" link → `/foods?meal=breakfast&date=2026-04-19`
4. **Empty bucket state:** "No foods logged yet" with "+ Add food" link

### Home page redirect

Update `PagesController#home` to redirect logged-in users to `/today` instead of `/settings/edit`.

## Add Food Flow

### Search page with meal context

When `/foods` receives `meal` and `date` query params:
1. Show "Adding to [Meal] · [Date]" header below the search bar
2. Search result rows become clickable — tapping one opens the bottom sheet
3. The bottom sheet is a Turbo Frame or Stimulus-managed overlay

### Bottom sheet

Triggered by clicking a search result when meal context is present. Contains:

1. **Food info:** name, source badge, per-100g calories
2. **Gram input:** large centered number field, default empty
3. **"This food" preview:** computed calories + Protein/Carbs/Fat/Fiber for entered grams. Updates live as user types (Stimulus controller).
4. **Swipeable tally card** (Stimulus controller with horizontal scroll snap):
   - **Page 1 — Meal tally:** projected meal totals (bold primary) with "currently X" secondary. Shows calories + all 4 macros.
   - **Page 2 — Daily tally:** projected daily totals (bold primary) with "currently X" secondary, progress bar, and /target values for each macro.
   - Dot indicators (2 dots) showing current page.
   - Tally values emphasize the *projected* (after-adding) values, with current values as secondary context.
5. **"Add to [Meal]" button:** submits the form

### Form submission

- Posts to `POST /days/:date/entries` with `food_id`, `meal`, `quantity_g`
- For local `Food` records: creates entry directly
- For USDA transient results (`Usda::FoodResult`): the bottom sheet form includes hidden fields with the USDA result data (fdc_id, name, calories, etc.). The controller calls `Usda::Client.persist` to save the food first, then creates the entry with the new food_id. The form distinguishes local foods (has `food_id`) from USDA transient results (has `usda_fdc_id` instead).
- On success: redirects to `/days/:date`

### Stimulus controllers needed

- `sheet_controller.js` — manages bottom sheet open/close, overlay
- `quantity_preview_controller.js` — live calorie/macro preview as user types grams
- `swipe_controller.js` — horizontal scroll snap for the tally card pages

## Edit / Delete Entry

### FoodLogEntriesController

- `edit` — renders edit page showing food name (read-only), editable gram input, live calorie preview, save button, delete button
- `update` — updates `quantity_g`, redirects to `/days/:date`
- `destroy` — deletes entry with confirmation, redirects to `/days/:date`

All actions scoped to `current_user.food_log_entries` for authorization.

## Testing

### FoodLogEntry Model Tests

- Validates presence of user, food, logged_on, meal, quantity_g
- Validates quantity_g > 0
- Computed calories are correct: `food.calories * quantity_g / 100`
- Computed protein, carbs, fat, fiber are correct
- Meal enum values work (breakfast, lunch, dinner, snacks)
- Belongs to user, belongs to food

### DaysController Tests

- `GET /today` redirects to `/days/[today's date]`
- `GET /days/:date` renders Today view with meal buckets
- Requires authentication (redirects to login)
- Shows entries grouped by meal with correct calorie subtotals
- Shows calorie summary card with consumed/target and progress bar
- Shows empty state for meals with no entries

### FoodLogEntriesController Tests

- `POST /days/:date/entries` creates entry with correct user, food, meal, quantity
- `POST` with invalid params (quantity_g = 0) returns error
- `PATCH /days/:date/entries/:id` updates quantity_g
- `DELETE /days/:date/entries/:id` destroys entry and redirects
- All actions scoped to current user (404 for other user's entries)

### Search with Meal Context Tests

- `GET /foods?meal=breakfast&date=2026-04-19` shows "Adding to Breakfast" context
- `GET /foods` without meal params shows normal search (no meal context)

## Out of Scope

- Date navigation / prev-next arrows (Ticket 19)
- Recipes (Ticket 20)
- Meal templates (Ticket 21)
- Quick re-log / recent/frequent tabs (Ticket 22)
- Turbo Stream live updates (use full page redirects for MVP — can enhance later)
- Swipe-to-delete on entry rows (use edit page with delete button)
