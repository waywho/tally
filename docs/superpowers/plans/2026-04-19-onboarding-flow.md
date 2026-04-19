# Onboarding Flow Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a 3-step onboarding wizard (welcome + name, calorie target, macro targets) that redirects new users until they complete or skip it.

**Architecture:** Multi-step wizard backed by the existing `User` model. An `onboarded_at` timestamp tracks completion. A `before_action` in `ApplicationController` enforces the redirect. Sliders use a Stimulus controller to sync range/number inputs. Fun display names are auto-generated on account creation.

**Tech Stack:** Rails 8, Haml, Stimulus, Tailwind CSS v4, Minitest, Capybara, factory_bot

---

## File Structure

| File | Responsibility |
|---|---|
| `db/migrate/TIMESTAMP_add_onboarded_at_to_users.rb` | Add onboarded_at column |
| `app/models/user.rb` | Add `generate_fun_name` class method |
| `app/misc/rodauth_main.rb` | Update hook to use fun name, update verify redirect |
| `app/controllers/application_controller.rb` | Add `ensure_onboarded` before_action |
| `app/controllers/onboarding_controller.rb` | Wizard step actions |
| `app/controllers/users_controller.rb` | Add `skip_before_action :ensure_onboarded` |
| `app/controllers/pages_controller.rb` | Add `skip_before_action :ensure_onboarded` |
| `config/routes.rb` | Onboarding routes |
| `config/locales/en.yml` | Flash messages |
| `app/views/onboarding/step1.html.haml` | Welcome + display name |
| `app/views/onboarding/step2.html.haml` | Calorie target with slider |
| `app/views/onboarding/step3.html.haml` | Macro targets with sliders |
| `app/javascript/controllers/slider_sync_controller.js` | Range ↔ number sync |
| `test/models/user_test.rb` | Fun name generator tests |
| `test/controllers/onboarding_controller_test.rb` | Controller tests |
| `test/integration/onboarding_redirect_test.rb` | before_action redirect tests |
| `test/system/onboarding_test.rb` | Capybara system tests |
| `test/application_system_test_case.rb` | Base class for system tests |

---

### Task 1: Add onboarded_at migration

**Files:**
- Create: `db/migrate/TIMESTAMP_add_onboarded_at_to_users.rb`

- [ ] **Step 1: Generate the migration**

Run: `bin/rails generate migration AddOnboardedAtToUsers onboarded_at:datetime`

- [ ] **Step 2: Edit the migration to backfill existing users**

Replace the generated migration content with:

```ruby
class AddOnboardedAtToUsers < ActiveRecord::Migration[8.1]
  def change
    add_column :users, :onboarded_at, :datetime, null: true, default: nil
    reversible do |dir|
      dir.up do
        User.update_all(onboarded_at: Time.current)
      end
    end
  end
end
```

- [ ] **Step 3: Run the migration**

Run: `bin/rails db:migrate`
Expected: Migration runs successfully.

- [ ] **Step 4: Run existing tests to check for regressions**

Run: `bin/rails test`
Expected: All 59 tests pass (0 failures, 0 errors)

- [ ] **Step 5: Commit**

```bash
git add db/migrate/ db/schema.rb
git commit -m "feat: add onboarded_at column to users table"
```

---

### Task 2: Fun display name generator

**Files:**
- Modify: `app/models/user.rb`
- Modify: `app/misc/rodauth_main.rb:135-137`
- Modify: `test/models/user_test.rb`

- [ ] **Step 1: Write the failing tests**

Add to the end of `test/models/user_test.rb` (before the final `end`):

```ruby
  # Fun name generator
  test "generate_fun_name returns an Adjective Animal string" do
    name = User.generate_fun_name
    assert_match(/\A\w+ \w+\z/, name)
  end

  test "generate_fun_name only uses allowed animals" do
    allowed = User::FUN_NAME_ANIMALS
    50.times do
      name = User.generate_fun_name
      animal = name.split(" ").last
      assert_includes allowed, animal, "#{animal} is not in the allowed animals list"
    end
  end

  test "generate_fun_name only uses positive adjectives" do
    allowed = User::FUN_NAME_ADJECTIVES
    50.times do
      name = User.generate_fun_name
      adjective = name.split(" ").first
      assert_includes allowed, adjective, "#{adjective} is not in the allowed adjectives list"
    end
  end
```

- [ ] **Step 2: Run the tests to verify they fail**

Run: `bin/rails test test/models/user_test.rb -n /fun_name/`
Expected: FAIL — `undefined method 'generate_fun_name'`

- [ ] **Step 3: Add the fun name generator to the User model**

In `app/models/user.rb`, add the constants and class method above the `private` keyword:

```ruby
class User < ApplicationRecord
  belongs_to :account

  enum :unit_preference, { metric: 0, imperial: 1 }, default: :metric

  FUN_NAME_ADJECTIVES = %w[
    Happy Brave Sunny Cheerful Mighty Radiant Gentle Bold Bright Lively
    Jolly Swift Calm Kind Merry Keen Wise Noble Spirited Zesty
  ].freeze

  FUN_NAME_ANIMALS = %w[
    Otter Fox Panda Owl Dolphin Rabbit Koala Penguin Falcon Hedgehog
    Deer Squirrel Robin Butterfly Hummingbird Lynx Seal Crane Gecko Sparrow
  ].freeze

  def self.generate_fun_name
    "#{FUN_NAME_ADJECTIVES.sample} #{FUN_NAME_ANIMALS.sample}"
  end

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

- [ ] **Step 4: Run the fun name tests to verify they pass**

Run: `bin/rails test test/models/user_test.rb -n /fun_name/`
Expected: 3 tests pass

- [ ] **Step 5: Update the Rodauth hook to use the fun name**

In `app/misc/rodauth_main.rb`, change the `after_create_account` hook from:

```ruby
    after_create_account do
      User.create!(account_id: account_id)
    end
```

to:

```ruby
    after_create_account do
      User.create!(account_id: account_id, display_name: User.generate_fun_name)
    end
```

- [ ] **Step 6: Run all tests**

Run: `bin/rails test`
Expected: All tests pass (0 failures, 0 errors)

- [ ] **Step 7: Commit**

```bash
git add app/models/user.rb app/misc/rodauth_main.rb test/models/user_test.rb
git commit -m "feat: add fun display name generator for new accounts"
```

---

### Task 3: Onboarding routes and controller

**Files:**
- Create: `app/controllers/onboarding_controller.rb`
- Modify: `config/routes.rb`
- Modify: `config/locales/en.yml`

- [ ] **Step 1: Add onboarding routes**

In `config/routes.rb`, add the onboarding resource after the settings line:

```ruby
Rails.application.routes.draw do
  root "pages#home"

  resource :settings, only: [:edit, :update], controller: "users"

  resource :onboarding, only: [], controller: "onboarding" do
    get :step1
    get :step2
    get :step3
    patch :update_step1
    patch :update_step2
    patch :finish
    post :skip
  end

  mount Lookbook::Engine, at: "/lookbook" if Rails.env.development?

  get "up" => "rails/health#show", as: :rails_health_check
end
```

- [ ] **Step 2: Add the flash message to locales**

In `config/locales/en.yml`, add to the `flash` section:

```yaml
en:
  flash:
    settings_saved: "Settings saved."
    account_created: "Your account has been created. Please check your email to verify your account."
    account_verified: "Your account has been verified successfully."
    onboarding_complete: "You're all set! Start tracking your nutrition."
```

- [ ] **Step 3: Create the OnboardingController**

Create `app/controllers/onboarding_controller.rb`:

```ruby
class OnboardingController < ApplicationController
  skip_before_action :ensure_onboarded
  before_action :require_authentication
  before_action :redirect_if_onboarded

  layout "authentication"

  def step1
    @user = current_user
  end

  def step2
    @user = current_user
  end

  def step3
    @user = current_user
  end

  def update_step1
    current_user.update!(display_name: params[:user][:display_name])
    redirect_to onboarding_step2_path
  end

  def update_step2
    current_user.update!(daily_calorie_target: params[:user][:daily_calorie_target])
    redirect_to onboarding_step3_path
  end

  def finish
    current_user.update!(
      protein_target: params[:user][:protein_target],
      carbs_target: params[:user][:carbs_target],
      fat_target: params[:user][:fat_target],
      fiber_target: params[:user][:fiber_target],
      onboarded_at: Time.current
    )
    redirect_to root_path, notice: t("flash.onboarding_complete")
  end

  def skip
    current_user.update!(onboarded_at: Time.current)
    redirect_to root_path
  end

  private

  def redirect_if_onboarded
    redirect_to root_path if current_user.onboarded_at.present?
  end
end
```

- [ ] **Step 4: Verify routes exist**

Run: `bin/rails routes -g onboarding`
Expected: Shows step1, step2, step3 (GET), update_step1, update_step2, finish (PATCH), skip (POST)

- [ ] **Step 5: Commit**

```bash
git add app/controllers/onboarding_controller.rb config/routes.rb config/locales/en.yml
git commit -m "feat: add onboarding controller and routes"
```

---

### Task 4: ensure_onboarded before_action

**Files:**
- Modify: `app/controllers/application_controller.rb`
- Modify: `app/controllers/users_controller.rb`
- Modify: `app/controllers/pages_controller.rb`
- Modify: `app/misc/rodauth_main.rb:151-152`

- [ ] **Step 1: Add ensure_onboarded to ApplicationController**

In `app/controllers/application_controller.rb`, add the `before_action` and the private method:

```ruby
class ApplicationController < ActionController::Base
  allow_browser versions: :modern
  stale_when_importmap_changes

  before_action :ensure_onboarded

  private

  def require_authentication
    rodauth.require_authentication
  end

  def ensure_onboarded
    return unless rodauth.logged_in?
    return if current_user&.onboarded_at.present?

    redirect_to onboarding_step1_path
  end

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

- [ ] **Step 2: Skip ensure_onboarded in UsersController**

In `app/controllers/users_controller.rb`, add the skip after the existing `before_action`:

```ruby
class UsersController < ApplicationController
  before_action :require_authentication
  skip_before_action :ensure_onboarded

  # ... rest unchanged
end
```

- [ ] **Step 3: Skip ensure_onboarded in PagesController**

In `app/controllers/pages_controller.rb`, add the skip:

```ruby
class PagesController < ApplicationController
  skip_before_action :ensure_onboarded

  def home
    if rodauth.logged_in?
      redirect_to edit_settings_path
    else
      redirect_to rodauth.login_path
    end
  end
end
```

- [ ] **Step 4: Update verify_account_redirect to go to onboarding**

In `app/misc/rodauth_main.rb`, change:

```ruby
    verify_account_redirect { "/settings/edit" }
```

to:

```ruby
    verify_account_redirect { "/" }
```

This way after verification, the user hits `/` → `pages#home` → redirects to settings (if onboarded) or the `ensure_onboarded` filter catches them and sends to onboarding (if not).

- [ ] **Step 5: Run existing tests**

Run: `bin/rails test`
Expected: All tests pass. The existing controller tests for `UsersController` should still work because they have `skip_before_action :ensure_onboarded` and their factory creates users with `onboarded_at: nil` — but the settings tests log in first, and the redirect may fire. If tests fail, update the user factory to include `onboarded_at { Time.current }` as a default (see Step 6).

- [ ] **Step 6: Update user factory with onboarded_at default**

If tests failed in Step 5, update `test/factories/users.rb`:

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
    onboarded_at { Time.current }

    trait :not_onboarded do
      onboarded_at { nil }
    end
  end
end
```

The default factory now creates onboarded users (so existing tests don't break). Use `create(:user, :not_onboarded)` for onboarding-specific tests.

- [ ] **Step 7: Run all tests again**

Run: `bin/rails test`
Expected: All tests pass (0 failures, 0 errors)

- [ ] **Step 8: Commit**

```bash
git add app/controllers/application_controller.rb app/controllers/users_controller.rb app/controllers/pages_controller.rb app/misc/rodauth_main.rb test/factories/users.rb
git commit -m "feat: add ensure_onboarded before_action to redirect new users"
```

---

### Task 5: Stimulus slider sync controller

**Files:**
- Create: `app/javascript/controllers/slider_sync_controller.js`

- [ ] **Step 1: Create the Stimulus controller**

Create `app/javascript/controllers/slider_sync_controller.js`:

```javascript
import { Controller } from "@hotwired/stimulus"

// Syncs a range input (slider) with a number input bidirectionally.
// Usage:
//   <div data-controller="slider-sync">
//     <input type="range" data-slider-sync-target="slider" data-action="input->slider-sync#syncFromSlider">
//     <input type="number" data-slider-sync-target="number" data-action="input->slider-sync#syncFromNumber">
//   </div>
export default class extends Controller {
  static targets = ["slider", "number"]

  syncFromSlider() {
    this.numberTarget.value = this.sliderTarget.value
  }

  syncFromNumber() {
    this.sliderTarget.value = this.numberTarget.value
  }
}
```

- [ ] **Step 2: Delete the hello_controller placeholder**

Run: `rm -f app/javascript/controllers/hello_controller.js`

The Stimulus eager loader auto-discovers controllers by filename convention — no manual registration needed.

- [ ] **Step 3: Verify the controller is loadable**

Run: `bin/rails runner "puts 'OK'"`
Expected: `OK` — no import errors.

- [ ] **Step 4: Commit**

```bash
git add app/javascript/controllers/slider_sync_controller.js
git add -u app/javascript/controllers/hello_controller.js
git commit -m "feat: add Stimulus slider-sync controller for range/number input sync"
```

---

### Task 6: Onboarding views

**Files:**
- Create: `app/views/onboarding/step1.html.haml`
- Create: `app/views/onboarding/step2.html.haml`
- Create: `app/views/onboarding/step3.html.haml`

- [ ] **Step 1: Create Step 1 view (Welcome + Display Name)**

Create `app/views/onboarding/step1.html.haml`:

```haml
.text-center.mb-6
  .flex.gap-1.5.justify-center
    %span.block.w-2.h-2.rounded-full.bg-primary
    %span.block.w-2.h-2.rounded-full.bg-border
    %span.block.w-2.h-2.rounded-full.bg-border

%h2.text-lg.font-semibold.text-text.text-center.mb-1 Welcome to Tally!
%p.text-sm.text-text-secondary.text-center.mb-6 Let's set up your profile and nutrition goals.

= form_with model: @user, url: onboarding_update_step1_path, method: :patch do |f|
  .mb-4
    = f.label :display_name, class: "label"
    = f.text_field :display_name, class: "input", placeholder: "Your name"
    %p.text-xs.text-text-secondary.mt-1 We picked a fun name for you — feel free to change it!

  = render ButtonComponent.new(label: "Continue", tag: :button, type: "submit", class: "w-full")

.mt-4.text-center
  = button_to "Skip and use defaults", onboarding_skip_path, method: :post, class: "text-sm text-text-secondary hover:text-primary cursor-pointer bg-transparent border-0"
```

- [ ] **Step 2: Create Step 2 view (Calorie Target)**

Create `app/views/onboarding/step2.html.haml`:

```haml
.text-center.mb-6
  .flex.gap-1.5.justify-center
    %span.block.w-2.h-2.rounded-full.bg-primary
    %span.block.w-2.h-2.rounded-full.bg-primary
    %span.block.w-2.h-2.rounded-full.bg-border

%h2.text-lg.font-semibold.text-text.text-center.mb-1 Daily Calorie Target
%p.text-sm.text-text-secondary.text-center.mb-6 How many calories are you aiming for each day?

= form_with model: @user, url: onboarding_update_step2_path, method: :patch do |f|
  .mb-6{"data-controller": "slider-sync"}
    .flex.justify-between.items-center.mb-2
      = f.label :daily_calorie_target, "Calories", class: "label mb-0"
      = f.number_field :daily_calorie_target, class: "w-20 text-center font-semibold border border-border rounded-md py-1 text-text", min: 1000, max: 5000, step: 50, "data-slider-sync-target": "number", "data-action": "input->slider-sync#syncFromNumber"
    = f.range_field :daily_calorie_target, min: 1000, max: 5000, step: 50, class: "w-full accent-primary", "data-slider-sync-target": "slider", "data-action": "input->slider-sync#syncFromSlider"
    .flex.justify-between.text-xs.text-text-secondary.mt-1
      %span 1,000
      %span 5,000

  .flex.gap-3
    = link_to "Back", onboarding_step1_path, class: "flex-1 inline-flex items-center justify-center font-semibold rounded-md transition-colors cursor-pointer px-4 py-2.5 text-base bg-white text-primary border border-primary hover:bg-primary-tint text-center"
    = render ButtonComponent.new(label: "Continue", tag: :button, type: "submit", class: "flex-1")

.mt-4.text-center
  = button_to "Skip and use defaults", onboarding_skip_path, method: :post, class: "text-sm text-text-secondary hover:text-primary cursor-pointer bg-transparent border-0"
```

- [ ] **Step 3: Create Step 3 view (Macro Targets)**

Create `app/views/onboarding/step3.html.haml`:

```haml
.text-center.mb-6
  .flex.gap-1.5.justify-center
    %span.block.w-2.h-2.rounded-full.bg-primary
    %span.block.w-2.h-2.rounded-full.bg-primary
    %span.block.w-2.h-2.rounded-full.bg-primary

%h2.text-lg.font-semibold.text-text.text-center.mb-1 Macro Targets
%p.text-sm.text-text-secondary.text-center.mb-6 Set your daily macro goals in grams.

= form_with model: @user, url: onboarding_finish_path, method: :patch do |f|
  -# Protein
  .mb-5{"data-controller": "slider-sync"}
    .flex.justify-between.items-center.mb-2
      = f.label :protein_target, "Protein (g)", class: "label mb-0"
      = f.number_field :protein_target, class: "w-16 text-center font-semibold border border-border rounded-md py-1 text-sm text-text", min: 0, max: 500, step: 5, "data-slider-sync-target": "number", "data-action": "input->slider-sync#syncFromNumber"
    = f.range_field :protein_target, min: 0, max: 500, step: 5, class: "w-full accent-primary", "data-slider-sync-target": "slider", "data-action": "input->slider-sync#syncFromSlider"

  -# Carbs
  .mb-5{"data-controller": "slider-sync"}
    .flex.justify-between.items-center.mb-2
      = f.label :carbs_target, "Carbs (g)", class: "label mb-0"
      = f.number_field :carbs_target, class: "w-16 text-center font-semibold border border-border rounded-md py-1 text-sm text-text", min: 0, max: 500, step: 5, "data-slider-sync-target": "number", "data-action": "input->slider-sync#syncFromNumber"
    = f.range_field :carbs_target, min: 0, max: 500, step: 5, class: "w-full accent-primary", "data-slider-sync-target": "slider", "data-action": "input->slider-sync#syncFromSlider"

  -# Fat
  .mb-5{"data-controller": "slider-sync"}
    .flex.justify-between.items-center.mb-2
      = f.label :fat_target, "Fat (g)", class: "label mb-0"
      = f.number_field :fat_target, class: "w-16 text-center font-semibold border border-border rounded-md py-1 text-sm text-text", min: 0, max: 500, step: 5, "data-slider-sync-target": "number", "data-action": "input->slider-sync#syncFromNumber"
    = f.range_field :fat_target, min: 0, max: 500, step: 5, class: "w-full accent-primary", "data-slider-sync-target": "slider", "data-action": "input->slider-sync#syncFromSlider"

  -# Fiber (additional health target)
  .border-t.border-border.pt-4.mt-2.mb-5
    %p.text-xs.text-text-secondary.uppercase.tracking-wide.mb-4 Additional health target
    .mb-0{"data-controller": "slider-sync"}
      .flex.justify-between.items-center.mb-2
        = f.label :fiber_target, "Fiber (g)", class: "label mb-0"
        = f.number_field :fiber_target, class: "w-16 text-center font-semibold border border-border rounded-md py-1 text-sm text-text", min: 0, max: 200, step: 5, "data-slider-sync-target": "number", "data-action": "input->slider-sync#syncFromNumber"
      = f.range_field :fiber_target, min: 0, max: 200, step: 5, class: "w-full accent-primary", "data-slider-sync-target": "slider", "data-action": "input->slider-sync#syncFromSlider"

  .flex.gap-3.mt-6
    = link_to "Back", onboarding_step2_path, class: "flex-1 inline-flex items-center justify-center font-semibold rounded-md transition-colors cursor-pointer px-4 py-2.5 text-base bg-white text-primary border border-primary hover:bg-primary-tint text-center"
    = render ButtonComponent.new(label: "Finish", tag: :button, type: "submit", class: "flex-1")

.mt-4.text-center
  = button_to "Skip and use defaults", onboarding_skip_path, method: :post, class: "text-sm text-text-secondary hover:text-primary cursor-pointer bg-transparent border-0"
```

- [ ] **Step 4: Verify the app loads without errors**

Run: `bin/rails runner "puts 'OK'"`
Expected: `OK`

- [ ] **Step 5: Commit**

```bash
git add app/views/onboarding/
git commit -m "feat: add onboarding wizard views with slider inputs"
```

---

### Task 7: Controller tests

**Files:**
- Create: `test/controllers/onboarding_controller_test.rb`

- [ ] **Step 1: Write controller tests**

Create `test/controllers/onboarding_controller_test.rb`:

```ruby
require "test_helper"

class OnboardingControllerTest < ActionDispatch::IntegrationTest
  setup do
    @account = create(:account)
    @user = create(:user, :not_onboarded, account: @account)
  end

  # Authentication
  test "step1 redirects when not authenticated" do
    get onboarding_step1_path
    assert_response :redirect
  end

  # Rendering steps
  test "step1 renders when not onboarded" do
    login(@account)
    get onboarding_step1_path
    assert_response :success
    assert_select "h2", "Welcome to Tally!"
  end

  test "step2 renders when not onboarded" do
    login(@account)
    get onboarding_step2_path
    assert_response :success
    assert_select "h2", "Daily Calorie Target"
  end

  test "step3 renders when not onboarded" do
    login(@account)
    get onboarding_step3_path
    assert_response :success
    assert_select "h2", "Macro Targets"
  end

  # Redirect if already onboarded
  test "step1 redirects to root when already onboarded" do
    @user.update!(onboarded_at: Time.current)
    login(@account)
    get onboarding_step1_path
    assert_redirected_to root_path
  end

  # update_step1
  test "update_step1 saves display name and redirects to step2" do
    login(@account)
    patch onboarding_update_step1_path, params: { user: { display_name: "New Name" } }
    assert_redirected_to onboarding_step2_path
    assert_equal "New Name", @user.reload.display_name
  end

  # update_step2
  test "update_step2 saves calorie target and redirects to step3" do
    login(@account)
    patch onboarding_update_step2_path, params: { user: { daily_calorie_target: 1800 } }
    assert_redirected_to onboarding_step3_path
    assert_equal 1800, @user.reload.daily_calorie_target
  end

  # finish
  test "finish saves macros and onboarded_at and redirects to root" do
    login(@account)
    patch onboarding_finish_path, params: {
      user: {
        protein_target: 60,
        carbs_target: 200,
        fat_target: 70,
        fiber_target: 25
      }
    }
    assert_redirected_to root_path
    assert_equal "You're all set! Start tracking your nutrition.", flash[:notice]

    @user.reload
    assert_equal 60, @user.protein_target
    assert_equal 200, @user.carbs_target
    assert_equal 70, @user.fat_target
    assert_equal 25, @user.fiber_target
    assert_not_nil @user.onboarded_at
  end

  # skip
  test "skip sets onboarded_at without changing other fields and redirects" do
    login(@account)
    original_calories = @user.daily_calorie_target
    post onboarding_skip_path
    assert_redirected_to root_path

    @user.reload
    assert_not_nil @user.onboarded_at
    assert_equal original_calories, @user.daily_calorie_target
  end

  private

  def login(account)
    post "/login", params: { email: account.email, password: "password" }
  end
end
```

- [ ] **Step 2: Run the controller tests**

Run: `bin/rails test test/controllers/onboarding_controller_test.rb`
Expected: All 9 tests pass (0 failures, 0 errors)

- [ ] **Step 3: Commit**

```bash
git add test/controllers/onboarding_controller_test.rb
git commit -m "test: add onboarding controller tests"
```

---

### Task 8: Integration tests for ensure_onboarded

**Files:**
- Create: `test/integration/onboarding_redirect_test.rb`

- [ ] **Step 1: Write integration tests**

Create `test/integration/onboarding_redirect_test.rb`:

```ruby
require "test_helper"

class OnboardingRedirectTest < ActionDispatch::IntegrationTest
  test "authenticated user without onboarded_at is redirected to onboarding" do
    account = create(:account)
    create(:user, :not_onboarded, account: account)
    login(account)

    get edit_settings_path
    assert_redirected_to onboarding_step1_path
  end

  test "authenticated user with onboarded_at is not redirected" do
    account = create(:account)
    create(:user, account: account) # factory default has onboarded_at set
    login(account)

    get edit_settings_path
    assert_response :success
  end

  test "unauthenticated user is not redirected to onboarding" do
    get root_path
    assert_redirected_to "/login"
  end

  test "full wizard flow completes without redirect loop" do
    account = create(:account)
    create(:user, :not_onboarded, account: account)
    login(account)

    # Should be redirected to onboarding from settings
    get edit_settings_path
    assert_redirected_to onboarding_step1_path

    # Complete step 1
    patch onboarding_update_step1_path, params: { user: { display_name: "Test" } }
    assert_redirected_to onboarding_step2_path

    # Complete step 2
    patch onboarding_update_step2_path, params: { user: { daily_calorie_target: 2000 } }
    assert_redirected_to onboarding_step3_path

    # Complete step 3
    patch onboarding_finish_path, params: {
      user: { protein_target: 50, carbs_target: 250, fat_target: 65, fiber_target: 30 }
    }
    assert_redirected_to root_path

    # Now should be able to access settings without redirect
    follow_redirect! # root -> settings (via PagesController)
    follow_redirect! # -> edit_settings_path
    assert_response :success
  end

  private

  def login(account)
    post "/login", params: { email: account.email, password: "password" }
  end
end
```

- [ ] **Step 2: Run the integration tests**

Run: `bin/rails test test/integration/onboarding_redirect_test.rb`
Expected: All 4 tests pass

- [ ] **Step 3: Run full test suite**

Run: `bin/rails test`
Expected: All tests pass (0 failures, 0 errors)

- [ ] **Step 4: Commit**

```bash
git add test/integration/onboarding_redirect_test.rb
git commit -m "test: add integration tests for onboarding redirect flow"
```

---

### Task 9: Capybara system tests

**Files:**
- Create: `test/application_system_test_case.rb`
- Create: `test/system/onboarding_test.rb`

- [ ] **Step 1: Create the application system test case**

Create `test/application_system_test_case.rb`:

```ruby
require "test_helper"

class ApplicationSystemTestCase < ActionDispatch::SystemTestCase
  driven_by :selenium, using: :headless_chrome, screen_size: [375, 812]

  def login_as(account)
    visit "/login"
    fill_in "email", with: account.email
    fill_in "password", with: "password"
    click_button "Login"
  end
end
```

- [ ] **Step 2: Write system tests**

Create `test/system/onboarding_test.rb`:

```ruby
require "application_system_test_case"

class OnboardingTest < ApplicationSystemTestCase
  setup do
    @account = create(:account)
    @user = create(:user, :not_onboarded, account: @account, display_name: "Happy Otter")
  end

  test "step 1 shows welcome and pre-filled fun name" do
    login_as(@account)
    assert_text "Welcome to Tally!"
    assert_field "user[display_name]", with: "Happy Otter"
    assert_text "We picked a fun name for you"
  end

  test "step 1 continue advances to step 2" do
    login_as(@account)
    fill_in "user[display_name]", with: "My Name"
    click_button "Continue"
    assert_text "Daily Calorie Target"
  end

  test "step 2 shows calorie slider and number input" do
    login_as(@account)
    click_button "Continue"
    assert_text "Daily Calorie Target"
    assert_selector "input[type='range'][name='user[daily_calorie_target]']"
    assert_selector "input[type='number'][name='user[daily_calorie_target]']"
  end

  test "step 2 back returns to step 1" do
    login_as(@account)
    click_button "Continue"
    click_link "Back"
    assert_text "Welcome to Tally!"
  end

  test "step 3 shows macro sliders with fiber separated" do
    login_as(@account)
    click_button "Continue"
    click_button "Continue"
    assert_text "Macro Targets"
    assert_selector "input[type='range'][name='user[protein_target]']"
    assert_selector "input[type='range'][name='user[carbs_target]']"
    assert_selector "input[type='range'][name='user[fat_target]']"
    assert_text "Additional health target"
    assert_selector "input[type='range'][name='user[fiber_target]']"
  end

  test "step 3 back returns to step 2" do
    login_as(@account)
    click_button "Continue"
    click_button "Continue"
    click_link "Back"
    assert_text "Daily Calorie Target"
  end

  test "skip on step 1 completes onboarding with defaults" do
    login_as(@account)
    click_button "Skip and use defaults"

    @user.reload
    assert_not_nil @user.onboarded_at
    assert_equal 2000, @user.daily_calorie_target
    assert_equal 50, @user.protein_target
  end

  test "full flow end-to-end" do
    login_as(@account)

    # Step 1
    fill_in "user[display_name]", with: "Test User"
    click_button "Continue"

    # Step 2
    assert_text "Daily Calorie Target"
    fill_in "user[daily_calorie_target]", with: "1800"
    click_button "Continue"

    # Step 3
    assert_text "Macro Targets"
    fill_in "user[protein_target]", with: "60"
    fill_in "user[carbs_target]", with: "200"
    fill_in "user[fat_target]", with: "70"
    fill_in "user[fiber_target]", with: "25"
    click_button "Finish"

    # Should complete and redirect
    assert_text "You're all set!"

    @user.reload
    assert_equal "Test User", @user.display_name
    assert_equal 1800, @user.daily_calorie_target
    assert_equal 60, @user.protein_target
    assert_equal 200, @user.carbs_target
    assert_equal 70, @user.fat_target
    assert_equal 25, @user.fiber_target
    assert_not_nil @user.onboarded_at
  end
end
```

- [ ] **Step 3: Run the system tests**

Run: `bin/rails test:system`
Expected: All 8 system tests pass

- [ ] **Step 4: Run the full test suite (unit + integration + system)**

Run: `bin/rails test && bin/rails test:system`
Expected: All tests pass (0 failures, 0 errors)

- [ ] **Step 5: Commit**

```bash
git add test/application_system_test_case.rb test/system/onboarding_test.rb
git commit -m "test: add Capybara system tests for onboarding wizard"
```

---

## Notes for implementers

- **Layout:** The onboarding controller uses `layout "authentication"` — the same centered layout with Tally wordmark used for login/signup. The dot indicators are rendered inside each step view, not in the layout.
- **Stimulus auto-discovery:** The `slider_sync_controller.js` file is auto-discovered by the eager loader configured in `app/javascript/controllers/index.js`. No manual registration is needed. The controller name is `slider-sync` (kebab-case from the filename).
- **Factory trait:** Use `create(:user, :not_onboarded)` for users who haven't completed onboarding. The default factory creates onboarded users to avoid breaking existing tests.
- **Form model binding:** `form_with model: @user` generates field names like `user[display_name]`. The controller reads `params[:user][:field_name]` — not strong params, since each step only updates specific known fields via `update!`.
- **Skip button:** Uses `button_to` (which generates a mini-form with POST) rather than a link, because skip is a state-changing action.
- **Back buttons:** Use `link_to` (GET requests) since going back is just navigation, not a state change. Styled to match ButtonComponent secondary scheme but implemented as plain links.
- **Haml:** All views use `.html.haml` extension. Follow existing patterns in `app/views/rodauth/`.
- **Range input `accent-primary`:** The `accent-primary` Tailwind class styles the native range slider thumb/track to use the primary green color.
