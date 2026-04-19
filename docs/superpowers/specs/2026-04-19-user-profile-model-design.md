# User Profile Model — Design Spec

## Goal

Add a `User` model that holds app-level profile data (nutrition targets, display name, preferences) separate from Rodauth's `Account` model. Provide a settings page where users can edit their profile.

## Architecture

Separate `User` model with a 1:1 `belongs_to :account` relationship. Rodauth owns authentication (`accounts` table); `User` owns app-level data. A `User` record is auto-created when an account is created via a Rodauth `after_create_account` hook.

## Data Model

### `users` table

| Column | Type | Default | Notes |
|---|---|---|---|
| `account_id` | bigint, FK | not null | unique, references accounts, on_delete: cascade |
| `display_name` | string | `""` | |
| `daily_calorie_target` | integer | `2000` | |
| `protein_target` | integer | `50` | grams |
| `carbs_target` | integer | `250` | grams |
| `fat_target` | integer | `65` | grams |
| `fiber_target` | integer | `30` | grams |
| `timezone` | string | `"UTC"` | IANA identifier via ActiveSupport::TimeZone |
| `unit_preference` | integer | `0` | enum: metric (0), imperial (1) |
| `country` | string | `nil` | ISO 3166-1 alpha-2, validated via `countries` gem |
| `language` | string | `"en"` | ISO 639-1, validated against I18n.available_locales |
| `timestamps` | | | created_at, updated_at |

Macro defaults are based on a rough 2000 cal balanced diet. Users will set their own targets during onboarding (Ticket 8).

### Associations

```ruby
# app/models/user.rb
class User < ApplicationRecord
  belongs_to :account
  enum :unit_preference, { metric: 0, imperial: 1 }, default: :metric
end

# app/models/account.rb (updated)
class Account < ApplicationRecord
  include Rodauth::Rails.model
  enum :status, { unverified: 1, verified: 2, closed: 3 }
  has_one :user, dependent: :destroy
end
```

### Validations

- `daily_calorie_target`: presence, numericality (1..10_000)
- `protein_target`, `carbs_target`, `fat_target`, `fiber_target`: presence, numericality (0..1_000)
- `timezone`: inclusion in `ActiveSupport::TimeZone` zone names
- `language`: inclusion in `I18n.available_locales` (as strings)
- `country`: validated via `ISO3166::Country` from the `countries` gem (when present)
- `display_name`: length (max 100)

## Auto-creation

In `app/misc/rodauth_main.rb`, add an `after_create_account` hook:

```ruby
after_create_account do
  User.create!(account_id: account_id)
end
```

This ensures every account always has a corresponding User record with sensible defaults.

## Gems

- `countries` — ISO 3166 country data and validation. Provides `ISO3166::Country` for validation and country name lookups.

Rails' built-in `I18n` handles language/locale — no extra gem needed.

## Routes

```ruby
resource :settings, only: [:edit, :update], controller: "users"
```

Produces:
- `GET /settings/edit` → `users#edit`
- `PATCH /settings` → `users#update`

## Controller

```ruby
# app/controllers/users_controller.rb
class UsersController < ApplicationController
  before_action :require_authentication

  def edit
    @user = current_user
  end

  def update
    @user = current_user
    if @user.update(user_params)
      redirect_to edit_settings_path, notice: "Settings saved."
    else
      render :edit, status: :unprocessable_entity
    end
  end
end
```

### `current_user` helper

Add to `ApplicationController`:

```ruby
def current_user
  @current_user ||= current_account&.user
end
helper_method :current_user
```

Controllers and views use `current_user` for app data and `current_account` (from Rodauth) for auth.

## Settings Page

Single page at `/settings/edit` with sections:

1. **Profile** — display name text field
2. **Nutrition Targets** — calorie, protein, carbs, fat, fiber (number inputs)
3. **Preferences** — timezone (select from ActiveSupport::TimeZone), unit preference (radio buttons: metric/imperial), country (select via `countries` gem), language (select from I18n.available_locales)
4. **Account** — links to Rodauth's change email (`rodauth.change_login_path`) and change password (`rodauth.change_password_path`) pages

Uses existing design system: CardComponent for sections, `.input` and `.label` CSS classes, ButtonComponent for submit.

## Testing

### Model tests (test/models/user_test.rb)
- Validates presence and range of calorie/macro targets
- Validates timezone inclusion
- Validates language inclusion
- Validates country via ISO3166 (when present)
- Validates display_name max length
- Tests unit_preference enum
- Tests association to account
- Tests factory validity

### Controller tests (test/controllers/users_controller_test.rb)
- `GET /settings/edit` requires authentication (redirects when logged out)
- `GET /settings/edit` renders form when logged in
- `PATCH /settings` with valid params updates and redirects with notice
- `PATCH /settings` with invalid params re-renders form with errors

### Integration test (test/integration/user_creation_test.rb)
- Creating an account via Rodauth automatically creates a User record with defaults

## Out of Scope

- Onboarding wizard (Ticket 8)
- Avatar/profile photo
- Applying locale/timezone to the app UI (future ticket — this ticket stores the values)
- Applying country to food search filtering (future M2 ticket — this ticket stores the value)
