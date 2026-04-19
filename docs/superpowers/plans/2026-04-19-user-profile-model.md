# User Profile Model Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a `User` model with nutrition targets and preferences, auto-created on account signup, with a settings page to edit profile data.

**Architecture:** Separate `User` model with 1:1 `belongs_to :account`. Rodauth owns `accounts`; `User` owns app-level profile data. Auto-created via Rodauth `after_create_account` hook. Settings page at `/settings/edit` using existing design system components.

**Tech Stack:** Rails 8, Rodauth, Minitest, factory_bot, `countries` gem, ViewComponent, Haml, Tailwind CSS

---

## File Structure

| File | Responsibility |
|---|---|
| `db/migrate/TIMESTAMP_create_users.rb` | Migration for users table |
| `app/models/user.rb` | User model with validations and enum |
| `app/models/account.rb` | Updated with `has_one :user` |
| `app/controllers/application_controller.rb` | `current_user` helper method |
| `app/controllers/users_controller.rb` | Settings edit/update actions |
| `app/views/users/edit.html.haml` | Settings page view |
| `app/misc/rodauth_main.rb` | `after_create_account` hook |
| `config/routes.rb` | Settings resource route |
| `test/factories/users.rb` | User factory |
| `test/models/user_test.rb` | Model validations and associations |
| `test/controllers/users_controller_test.rb` | Controller tests |
| `test/integration/user_creation_test.rb` | Auto-creation integration test |
| `Gemfile` | Add `countries` gem |

---

### Task 1: Add `countries` gem

**Files:**
- Modify: `Gemfile`

- [ ] **Step 1: Add the gem to the Gemfile**

Add to the top-level gems section (after the `view_component` line):

```ruby
# ISO 3166 country data [https://github.com/countries/countries]
gem "countries"
```

- [ ] **Step 2: Install the gem**

Run: `bundle install`
Expected: `countries` gem installed successfully, `Bundle complete!`

- [ ] **Step 3: Commit**

```bash
git add Gemfile Gemfile.lock
git commit -m "feat: add countries gem for ISO 3166 country data"
```

---

### Task 2: Create User model with migration

**Files:**
- Create: `db/migrate/TIMESTAMP_create_users.rb` (via generator)
- Create: `app/models/user.rb` (via generator)
- Modify: `app/models/account.rb`
- Create: `test/factories/users.rb`

- [ ] **Step 1: Generate the model**

Run: `bin/rails generate model User account:references display_name:string daily_calorie_target:integer protein_target:integer carbs_target:integer fat_target:integer fiber_target:integer timezone:string unit_preference:integer country:string language:string`

This creates the migration file, model file, and test file.

- [ ] **Step 2: Edit the migration to add defaults, unique index, and foreign key options**

Replace the generated migration content with:

```ruby
class CreateUsers < ActiveRecord::Migration[8.1]
  def change
    create_table :users do |t|
      t.references :account, null: false, foreign_key: { on_delete: :cascade }, index: { unique: true }
      t.string :display_name, default: "", null: false
      t.integer :daily_calorie_target, default: 2000, null: false
      t.integer :protein_target, default: 50, null: false
      t.integer :carbs_target, default: 250, null: false
      t.integer :fat_target, default: 65, null: false
      t.integer :fiber_target, default: 30, null: false
      t.string :timezone, default: "UTC", null: false
      t.integer :unit_preference, default: 0, null: false
      t.string :country
      t.string :language, default: "en", null: false

      t.timestamps
    end
  end
end
```

- [ ] **Step 3: Run the migration**

Run: `bin/rails db:migrate`
Expected: `CreateUsers: migrated`

- [ ] **Step 4: Write the User model with validations and enum**

Replace the generated `app/models/user.rb` with:

```ruby
class User < ApplicationRecord
  belongs_to :account

  enum :unit_preference, { metric: 0, imperial: 1 }, default: :metric

  validates :daily_calorie_target, presence: true,
    numericality: { only_integer: true, in: 1..10_000 }
  validates :protein_target, :carbs_target, :fat_target, :fiber_target,
    presence: true,
    numericality: { only_integer: true, in: 0..1_000 }
  validates :timezone, presence: true,
    inclusion: { in: ActiveSupport::TimeZone::MAPPING.keys }
  validates :language, presence: true,
    inclusion: { in: ->(_) { I18n.available_locales.map(&:to_s) } }
  validates :country, allow_blank: true,
    format: { with: /\A[A-Z]{2}\z/, message: "must be a valid ISO 3166-1 alpha-2 code" }
  validate :country_must_be_valid_iso3166, if: -> { country.present? }
  validates :display_name, length: { maximum: 100 }

  private

  def country_must_be_valid_iso3166
    unless ISO3166::Country.new(country)
      errors.add(:country, "is not a valid country code")
    end
  end
end
```

- [ ] **Step 5: Update Account model with `has_one :user`**

Replace the contents of `app/models/account.rb` with:

```ruby
class Account < ApplicationRecord
  include Rodauth::Rails.model
  enum :status, { unverified: 1, verified: 2, closed: 3 }
  has_one :user, dependent: :destroy
end
```

- [ ] **Step 6: Create the User factory**

Create `test/factories/users.rb`:

```ruby
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
```

- [ ] **Step 7: Verify the migration and model load correctly**

Run: `bin/rails runner "puts User.column_names.inspect"`
Expected: Output includes `"account_id"`, `"display_name"`, `"daily_calorie_target"`, `"protein_target"`, `"carbs_target"`, `"fat_target"`, `"fiber_target"`, `"timezone"`, `"unit_preference"`, `"country"`, `"language"`

- [ ] **Step 8: Commit**

```bash
git add db/migrate/ app/models/user.rb app/models/account.rb test/factories/users.rb db/schema.rb test/models/user_test.rb
git commit -m "feat: add User model with nutrition targets and preferences"
```

---

### Task 3: User model tests

**Files:**
- Create: `test/models/user_test.rb`

- [ ] **Step 1: Write model tests**

Replace the generated `test/models/user_test.rb` with:

```ruby
require "test_helper"

class UserTest < ActiveSupport::TestCase
  test "factory is valid" do
    user = build(:user)
    assert user.valid?, user.errors.full_messages.join(", ")
  end

  test "belongs to account" do
    user = create(:user)
    assert_instance_of Account, user.account
  end

  test "account has one user" do
    user = create(:user)
    assert_equal user, user.account.user
  end

  test "destroying account destroys user" do
    user = create(:user)
    account = user.account
    account.destroy
    assert_not User.exists?(user.id)
  end

  # daily_calorie_target validations
  test "invalid without daily_calorie_target" do
    user = build(:user, daily_calorie_target: nil)
    assert_not user.valid?
    assert_includes user.errors[:daily_calorie_target], "can't be blank"
  end

  test "daily_calorie_target must be at least 1" do
    user = build(:user, daily_calorie_target: 0)
    assert_not user.valid?
    assert user.errors[:daily_calorie_target].any?
  end

  test "daily_calorie_target must be at most 10000" do
    user = build(:user, daily_calorie_target: 10_001)
    assert_not user.valid?
    assert user.errors[:daily_calorie_target].any?
  end

  # macro target validations
  %i[protein_target carbs_target fat_target fiber_target].each do |attr|
    test "invalid without #{attr}" do
      user = build(:user, attr => nil)
      assert_not user.valid?
      assert_includes user.errors[attr], "can't be blank"
    end

    test "#{attr} must be at least 0" do
      user = build(:user, attr => -1)
      assert_not user.valid?
      assert user.errors[attr].any?
    end

    test "#{attr} must be at most 1000" do
      user = build(:user, attr => 1001)
      assert_not user.valid?
      assert user.errors[attr].any?
    end
  end

  # timezone validation
  test "invalid with unknown timezone" do
    user = build(:user, timezone: "Mars/Olympus")
    assert_not user.valid?
    assert user.errors[:timezone].any?
  end

  test "valid with known timezone" do
    user = build(:user, timezone: "Eastern Time (US & Canada)")
    assert user.valid?
  end

  # language validation
  test "invalid with unsupported language" do
    user = build(:user, language: "klingon")
    assert_not user.valid?
    assert user.errors[:language].any?
  end

  test "valid with supported language" do
    user = build(:user, language: "en")
    assert user.valid?
  end

  # country validation
  test "valid without country" do
    user = build(:user, country: nil)
    assert user.valid?
  end

  test "valid with known country code" do
    user = build(:user, country: "GB")
    assert user.valid?
  end

  test "invalid with unknown country code" do
    user = build(:user, country: "ZZ")
    assert_not user.valid?
    assert user.errors[:country].any?
  end

  test "invalid with lowercase country code" do
    user = build(:user, country: "gb")
    assert_not user.valid?
    assert user.errors[:country].any?
  end

  # display_name validation
  test "valid with blank display name" do
    user = build(:user, display_name: "")
    assert user.valid?
  end

  test "invalid with display name over 100 characters" do
    user = build(:user, display_name: "a" * 101)
    assert_not user.valid?
    assert user.errors[:display_name].any?
  end

  # unit_preference enum
  test "default unit preference is metric" do
    user = User.new
    assert user.metric?
  end

  test "can set unit preference to imperial" do
    user = build(:user, unit_preference: :imperial)
    assert user.imperial?
  end
end
```

- [ ] **Step 2: Run the tests**

Run: `bin/rails test test/models/user_test.rb`
Expected: All tests pass (0 failures, 0 errors)

- [ ] **Step 3: Commit**

```bash
git add test/models/user_test.rb
git commit -m "test: add User model validation and association tests"
```

---

### Task 4: Rodauth auto-creation hook

**Files:**
- Modify: `app/misc/rodauth_main.rb:130-137`
- Create: `test/integration/user_creation_test.rb`

- [ ] **Step 1: Write the integration test**

Create `test/integration/user_creation_test.rb`:

```ruby
require "test_helper"

class UserCreationTest < ActionDispatch::IntegrationTest
  test "creating an account automatically creates a user with defaults" do
    post "/create-account", params: {
      email: "auto-create@example.com",
      password: "password123",
      "password-confirm": "password123"
    }
    assert_response :redirect

    account = Account.find_by(email: "auto-create@example.com")
    assert account, "Account should be created"

    user = account.user
    assert user, "User should be auto-created"
    assert_equal 2000, user.daily_calorie_target
    assert_equal 50, user.protein_target
    assert_equal 250, user.carbs_target
    assert_equal 65, user.fat_target
    assert_equal 30, user.fiber_target
    assert_equal "UTC", user.timezone
    assert user.metric?
    assert_equal "en", user.language
    assert_nil user.country
    assert_equal "", user.display_name
  end
end
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `bin/rails test test/integration/user_creation_test.rb`
Expected: FAIL — `User should be auto-created` assertion fails because the hook doesn't exist yet.

- [ ] **Step 3: Add the after_create_account hook to Rodauth**

In `app/misc/rodauth_main.rb`, find the commented-out hook section (around line 134):

```ruby
    # Perform additional actions after the account is created.
    # after_create_account do
    #   Profile.create!(account_id: account_id, name: param("name"))
    # end
```

Replace it with:

```ruby
    # Perform additional actions after the account is created.
    after_create_account do
      User.create!(account_id: account_id)
    end
```

- [ ] **Step 4: Run the test to verify it passes**

Run: `bin/rails test test/integration/user_creation_test.rb`
Expected: PASS

- [ ] **Step 5: Run the full test suite to check for regressions**

Run: `bin/rails test`
Expected: All tests pass (0 failures, 0 errors)

- [ ] **Step 6: Commit**

```bash
git add app/misc/rodauth_main.rb test/integration/user_creation_test.rb
git commit -m "feat: auto-create User record on account signup via Rodauth hook"
```

---

### Task 5: current_user helper and settings route

**Files:**
- Modify: `app/controllers/application_controller.rb`
- Modify: `config/routes.rb`

- [ ] **Step 1: Add current_user helper to ApplicationController**

Replace the contents of `app/controllers/application_controller.rb` with:

```ruby
class ApplicationController < ActionController::Base
  # Only allow modern browsers supporting webp images, web push, badges, import maps, CSS nesting, and CSS :has.
  allow_browser versions: :modern

  # Changes to the importmap will invalidate the etag for HTML responses
  stale_when_importmap_changes

  private

  def current_user
    @current_user ||= current_account&.user
  end
  helper_method :current_user

  def current_account
    @current_account ||= Account.find_by(id: rodauth.session_value)
  end
  helper_method :current_account
end
```

- [ ] **Step 2: Add settings route**

In `config/routes.rb`, add the settings resource after the `root` line:

```ruby
Rails.application.routes.draw do
  # Define your application routes per the DSL in https://guides.rubyonrails.org/routing.html

  root "pages#home"

  resource :settings, only: [:edit, :update], controller: "users"

  mount Lookbook::Engine, at: "/lookbook" if Rails.env.development?

  # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
  # Can be used by load balancers and uptime monitors to verify that the app is live.
  get "up" => "rails/health#show", as: :rails_health_check

  # Render dynamic PWA files from app/views/pwa/* (remember to link manifest in application.html.erb)
  # get "manifest" => "rails/pwa#manifest", as: :pwa_manifest
  # get "service-worker" => "rails/pwa#service_worker", as: :pwa_service_worker

  # Defines the root path route ("/")
  # root "posts#index"
end
```

- [ ] **Step 3: Verify the route exists**

Run: `bin/rails routes -g settings`
Expected: Shows `edit_settings GET /settings/edit(.:format) users#edit` and `settings PATCH /settings(.:format) users#update`

- [ ] **Step 4: Commit**

```bash
git add app/controllers/application_controller.rb config/routes.rb
git commit -m "feat: add current_user helper and settings route"
```

---

### Task 6: Users controller and settings view

**Files:**
- Create: `app/controllers/users_controller.rb`
- Create: `app/views/users/edit.html.haml`

- [ ] **Step 1: Create the UsersController**

Create `app/controllers/users_controller.rb`:

```ruby
class UsersController < ApplicationController
  before_action { rodauth.require_authentication }

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

  private

  def user_params
    params.require(:user).permit(
      :display_name,
      :daily_calorie_target, :protein_target, :carbs_target, :fat_target, :fiber_target,
      :timezone, :unit_preference, :country, :language
    )
  end
end
```

- [ ] **Step 2: Create the settings view**

Create `app/views/users/edit.html.haml`:

```haml
- @page_title = "Settings"

= form_with model: @user, url: settings_path, method: :patch do |f|
  -# Profile section
  = render CardComponent.new(class: "p-6 mb-6") do
    %h2.text-lg.font-semibold.text-text.mb-4 Profile
    .mb-4
      = f.label :display_name, class: "label"
      = f.text_field :display_name, class: "input", placeholder: "Your name"
      - if @user.errors[:display_name].any?
        %p.field-error= @user.errors[:display_name].first

  -# Nutrition Targets section
  = render CardComponent.new(class: "p-6 mb-6") do
    %h2.text-lg.font-semibold.text-text.mb-4 Nutrition Targets
    .mb-4
      = f.label :daily_calorie_target, "Daily calorie target", class: "label"
      = f.number_field :daily_calorie_target, class: "input", min: 1, max: 10000, step: 1
      - if @user.errors[:daily_calorie_target].any?
        %p.field-error= @user.errors[:daily_calorie_target].first
    .grid.grid-cols-2.gap-4
      .mb-4
        = f.label :protein_target, "Protein (g)", class: "label"
        = f.number_field :protein_target, class: "input", min: 0, max: 1000, step: 1
        - if @user.errors[:protein_target].any?
          %p.field-error= @user.errors[:protein_target].first
      .mb-4
        = f.label :carbs_target, "Carbs (g)", class: "label"
        = f.number_field :carbs_target, class: "input", min: 0, max: 1000, step: 1
        - if @user.errors[:carbs_target].any?
          %p.field-error= @user.errors[:carbs_target].first
      .mb-4
        = f.label :fat_target, "Fat (g)", class: "label"
        = f.number_field :fat_target, class: "input", min: 0, max: 1000, step: 1
        - if @user.errors[:fat_target].any?
          %p.field-error= @user.errors[:fat_target].first
      .mb-4
        = f.label :fiber_target, "Fiber (g)", class: "label"
        = f.number_field :fiber_target, class: "input", min: 0, max: 1000, step: 1
        - if @user.errors[:fiber_target].any?
          %p.field-error= @user.errors[:fiber_target].first

  -# Preferences section
  = render CardComponent.new(class: "p-6 mb-6") do
    %h2.text-lg.font-semibold.text-text.mb-4 Preferences
    .mb-4
      = f.label :timezone, class: "label"
      = f.time_zone_select :timezone, nil, {}, class: "input"
      - if @user.errors[:timezone].any?
        %p.field-error= @user.errors[:timezone].first
    .mb-4
      = f.label :unit_preference, "Units", class: "label"
      .flex.gap-4.mt-1
        %label.flex.items-center.gap-2.text-sm.text-text.cursor-pointer
          = f.radio_button :unit_preference, "metric", class: "accent-primary"
          Metric
        %label.flex.items-center.gap-2.text-sm.text-text.cursor-pointer
          = f.radio_button :unit_preference, "imperial", class: "accent-primary"
          Imperial
    .mb-4
      = f.label :country, class: "label"
      = f.select :country, ISO3166::Country.all.sort_by(&:common_name).map { |c| [c.common_name, c.alpha2] }, { include_blank: "Select a country" }, class: "input"
      - if @user.errors[:country].any?
        %p.field-error= @user.errors[:country].first
    .mb-4
      = f.label :language, class: "label"
      = f.select :language, I18n.available_locales.map { |l| [l.to_s.upcase, l.to_s] }, {}, class: "input"
      - if @user.errors[:language].any?
        %p.field-error= @user.errors[:language].first

  -# Submit
  .mb-6
    = render ButtonComponent.new(label: "Save settings", tag: :button, type: "submit", class: "w-full")

  -# Account section
  = render CardComponent.new(class: "p-6") do
    %h2.text-lg.font-semibold.text-text.mb-4 Account
    .space-y-3
      %p.text-sm
        %a.text-primary.font-medium{href: rodauth.change_login_path} Change email
      %p.text-sm
        %a.text-primary.font-medium{href: rodauth.change_password_path} Change password
```

- [ ] **Step 3: Verify the page loads in development**

Run: `bin/rails runner "puts 'OK'"`
Expected: `OK` — no syntax errors in the new files.

- [ ] **Step 4: Commit**

```bash
git add app/controllers/users_controller.rb app/views/users/edit.html.haml
git commit -m "feat: add settings page with profile, nutrition targets, and preferences"
```

---

### Task 7: Controller and integration tests

**Files:**
- Create: `test/controllers/users_controller_test.rb`

- [ ] **Step 1: Write controller tests**

Create `test/controllers/users_controller_test.rb`:

```ruby
require "test_helper"

class UsersControllerTest < ActionDispatch::IntegrationTest
  setup do
    @account = create(:account)
    @user = create(:user, account: @account)
  end

  test "edit redirects when not authenticated" do
    get edit_settings_path
    assert_response :redirect
  end

  test "edit renders settings form when authenticated" do
    login(@account)
    get edit_settings_path
    assert_response :success
    assert_select "h2", "Profile"
    assert_select "h2", "Nutrition Targets"
    assert_select "h2", "Preferences"
    assert_select "h2", "Account"
    assert_select "input[name='user[display_name]']"
    assert_select "input[name='user[daily_calorie_target]']"
    assert_select "select[name='user[timezone]']"
  end

  test "update with valid params saves and redirects" do
    login(@account)
    patch settings_path, params: {
      user: {
        display_name: "New Name",
        daily_calorie_target: 1800,
        protein_target: 60,
        carbs_target: 200,
        fat_target: 70,
        fiber_target: 25,
        timezone: "London",
        unit_preference: "imperial",
        country: "GB",
        language: "en"
      }
    }
    assert_redirected_to edit_settings_path
    assert_equal "Settings saved.", flash[:notice]

    @user.reload
    assert_equal "New Name", @user.display_name
    assert_equal 1800, @user.daily_calorie_target
    assert_equal 60, @user.protein_target
    assert_equal 200, @user.carbs_target
    assert_equal 70, @user.fat_target
    assert_equal 25, @user.fiber_target
    assert_equal "London", @user.timezone
    assert @user.imperial?
    assert_equal "GB", @user.country
  end

  test "update with invalid params re-renders form" do
    login(@account)
    patch settings_path, params: {
      user: { daily_calorie_target: -1 }
    }
    assert_response :unprocessable_entity
    assert_select "p.field-error"
  end

  private

  def login(account)
    post "/login", params: { email: account.email, password: "password" }
  end
end
```

- [ ] **Step 2: Run the controller tests**

Run: `bin/rails test test/controllers/users_controller_test.rb`
Expected: All 4 tests pass (0 failures, 0 errors)

- [ ] **Step 3: Run the full test suite**

Run: `bin/rails test`
Expected: All tests pass (0 failures, 0 errors)

- [ ] **Step 4: Commit**

```bash
git add test/controllers/users_controller_test.rb
git commit -m "test: add controller tests for settings page"
```

---

## Notes for implementers

- **Rodauth auth in controllers:** Use `rodauth.require_authentication` in a `before_action` block (or inline). Access the current account via `Account.find_by(id: rodauth.session_value)`.
- **ViewComponent generator convention:** Per CLAUDE.md, always use `bin/rails generate view_component:component` for new components. This ticket doesn't create new components — it reuses existing `CardComponent` and `ButtonComponent`.
- **Haml templates:** All views use `.html.haml` extension. Follow existing patterns in `app/views/rodauth/`.
- **Factory pattern:** The existing account factory uses `RodauthApp.rodauth.allocate.password_hash("password")` for the password hash. The login helper in tests posts to `/login` with plaintext `"password"`.
- **`countries` gem:** Use `ISO3166::Country.new(code)` for validation — returns `nil` for invalid codes. Use `ISO3166::Country.all` for select options.
- **Timezone select:** Rails provides `f.time_zone_select` which uses `ActiveSupport::TimeZone::MAPPING` keys. The validation must match — validate against `ActiveSupport::TimeZone::MAPPING.keys`.
