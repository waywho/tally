# Meal Templates — Design Spec

## Goal

Allow users to save a meal bucket's entries as a reusable template, then one-tap log the entire template into any meal on any day. Templates appear on the search page when adding food.

## Architecture

A MealTemplate stores a named set of foods + weights. Templates are created from existing meal bucket entries on the Today view ("Save as template"). When logging, the controller creates FoodLogEntries for all template items in one action. Templates are meal-agnostic — the user chooses which meal to log into at the time of logging.

## Data Model

### MealTemplate

| Column | Type | Constraints |
|--------|------|-------------|
| `user_id` | references | required, FK to users, on_delete: cascade |
| `name` | string | required, max 255 |
| timestamps | | |

**Associations:**
- `belongs_to :user`
- `has_many :meal_template_items, dependent: :destroy`
- User `has_many :meal_templates, dependent: :destroy`

### MealTemplateItem

| Column | Type | Constraints |
|--------|------|-------------|
| `meal_template_id` | references | required, FK to meal_templates, on_delete: cascade |
| `food_id` | references | required, FK to foods |
| `weight` | decimal(8,2) | required, > 0 |
| timestamps | | |

**Associations:**
- `belongs_to :meal_template`
- `belongs_to :food`

## Creating a Template

### Entry point
Each meal bucket on the Today view that has entries shows a "Save as template" link. This links to:
```
GET /meal_templates/new?date=2026-04-21&meal=breakfast
```

### New template form
- Pre-fills the name field with a default like "Breakfast — Apr 21"
- Shows a read-only list of the foods + weights from that meal bucket
- User can edit the name
- On submit, creates MealTemplate + MealTemplateItems mirroring the meal's FoodLogEntries

### Controller logic for `new`
Load the current user's FoodLogEntries for the given date + meal. Pass them to the view as preview. On `create`, iterate over the entries and build MealTemplateItems with each entry's food_id and weight.

## Logging a Template

### Entry point
On the search page with meal context (`/foods?meal=breakfast&date=2026-04-21`), show a "Templates" section above search results listing the user's templates.

Each template row shows:
- Template name
- Total calories (sum of item calories)
- Number of items
- "Log" button

### Log action
`POST /meal_templates/:id/log` with params `date` and `meal`.

The controller:
1. Finds the template (scoped to current_user)
2. For each MealTemplateItem, creates a FoodLogEntry with:
   - `user: current_user`
   - `food_id: item.food_id`
   - `weight: item.weight`
   - `meal: params[:meal]`
   - `logged_on: params[:date]`
3. Redirects to `day_path(date: params[:date])` with flash notice

## Managing Templates

- `GET /meal_templates` — list all user's templates with item count and total calories. Accessible from a link on the search page or settings.
- `DELETE /meal_templates/:id` — delete a template with confirmation
- No edit for MVP — user can delete and re-save from a meal (Ticket 37 adds build-from-scratch which enables full editing)

## Routes

```ruby
resources :meal_templates, only: [:index, :new, :create, :destroy] do
  member do
    post :log
  end
end
```

## Views

### Today view modification
Add "Save as template" link to each meal bucket that has entries. Links to `new_meal_template_path(date: @date.iso8601, meal: meal)`.

### Search page modification
When meal context is present and user has templates, show a "Templates" section above the Turbo Frame search results:
- List of templates with name, total calories, item count
- Each has a form button that POSTs to `log_meal_template_path(template)` with hidden `date` and `meal` fields

### `/meal_templates` index page
List of all templates with name, item count, total calories, delete button.

### `/meal_templates/new` page
- Name field (pre-filled)
- Read-only list of foods + weights being saved
- Submit button

## Testing

### MealTemplate Model Tests
- Validates presence of name, user
- Has many meal_template_items, dependent: destroy
- Belongs to user

### MealTemplateItem Model Tests
- Validates presence of food, weight
- Validates weight > 0
- Belongs to meal_template, belongs to food

### MealTemplatesController Tests
- `GET /meal_templates` lists user's templates, not others'
- `GET /meal_templates/new?date=...&meal=...` pre-fills from meal entries
- `GET /meal_templates/new` without entries shows empty state
- `POST /meal_templates` creates template + items from meal entries
- `POST /meal_templates/:id/log` creates FoodLogEntries for all items in the specified meal + date
- `POST /meal_templates/:id/log` returns 404 for other user's template
- `DELETE /meal_templates/:id` destroys template
- `DELETE /meal_templates/:id` returns 404 for other user's template

### Search Page Integration Tests
- Templates section appears on search page when meal context is present and user has templates
- Templates section hidden when no meal context
- Templates section hidden when user has no templates

## Out of Scope
- Build templates from scratch (Ticket 37)
- Edit template (delete + re-save for MVP)
- Auto-suggest converting frequent combos to templates (v2)
- Template categories or tags
- Sharing templates between users
