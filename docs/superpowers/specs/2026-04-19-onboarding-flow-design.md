# Onboarding Flow — Design Spec

## Goal

Add a 3-step onboarding wizard for new users to set their display name, calorie target, and macro targets. Users who haven't completed onboarding are redirected to the wizard on any authenticated page load.

## Architecture

Multi-step wizard backed by the existing `User` model. Each step submits via PATCH to update the user record. An `onboarded_at` timestamp on the `users` table tracks completion — nil means onboarding is needed. A `before_action` in `ApplicationController` enforces the redirect.

Sliders are implemented with a Stimulus controller that syncs a range input with a number input bidirectionally.

## Schema Change

Add `onboarded_at` (datetime, nullable, default nil) to the `users` table.

Existing users (if any) should be backfilled with the current timestamp so they aren't forced into onboarding.

## Onboarding Detection

A `before_action` in `ApplicationController` checks `current_user&.onboarded_at`. If nil and the user is logged in, redirect to `/onboarding/step1`.

Skipped for:
- The `OnboardingController` itself
- Rodauth routes (handled by `RodauthController`)
- Health check route

## Routes

```ruby
resource :onboarding, only: [], controller: "onboarding" do
  get :step1
  get :step2
  get :step3
  patch :update_step1
  patch :update_step2
  patch :finish
  post :skip
end
```

## Controller

```ruby
# app/controllers/onboarding_controller.rb
class OnboardingController < ApplicationController
  skip_before_action :ensure_onboarded
  before_action :require_authentication
  before_action :redirect_if_onboarded

  def step1; end
  def step2; end
  def step3; end

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
    redirect_to root_path
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

## Views

All 3 steps use the `authentication` layout (centered, Tally wordmark). Each step is a full-page section with dot indicators showing progress.

### Step 1 — Welcome + Display Name (`onboarding/step1.html.haml`)

- Tally wordmark (from layout)
- Dot indicators: ● ○ ○
- Heading: "Welcome to Tally!"
- Subtext: "Let's set up your profile and nutrition goals."
- Display name text field, pre-filled with the auto-generated fun name
- Continue button → PATCH update_step1
- "Skip and use defaults" link → POST skip

### Step 2 — Calorie Target (`onboarding/step2.html.haml`)

- Dot indicators: ● ● ○
- Heading: "Daily Calorie Target"
- Subtext: "How many calories are you aiming for each day?"
- Slider (range input) + number input, synced via Stimulus controller
  - Range: 1,000–5,000, step: 50
  - Default: 2,000 (from user record)
- Back link → GET step1
- Continue button → PATCH update_step2
- "Skip and use defaults" link → POST skip

### Step 3 — Macro Targets (`onboarding/step3.html.haml`)

- Dot indicators: ● ● ●
- Heading: "Macro Targets"
- Subtext: "Set your daily macro goals in grams."
- Protein slider + number (range 0–500, default 50g)
- Carbs slider + number (range 0–500, default 250g)
- Fat slider + number (range 0–500, default 65g)
- Divider with "Additional health target" label
- Fiber slider + number (range 0–200, default 30g)
- All synced via the same Stimulus controller
- Back link → GET step2
- Finish button → PATCH finish
- "Skip and use defaults" link → POST skip

## Stimulus Controller

```javascript
// app/javascript/controllers/slider_sync_controller.js
// Connects range input and number input bidirectionally.
// Targets: slider (range input), number (number input)
// When slider changes → update number. When number changes → update slider.
```

Registered in the importmap. Used on Steps 2 and 3.

## Fun Display Name Generator

On User creation (in the `after_create_account` hook or the User model), generate a fun display name from curated arrays:

**Positive adjectives (~20):** Happy, Brave, Sunny, Cheerful, Mighty, Radiant, Gentle, Bold, Bright, Lively, Jolly, Swift, Calm, Kind, Merry, Keen, Wise, Noble, Spirited, Zesty

**Friendly animals (~20):** Otter, Fox, Panda, Owl, Dolphin, Rabbit, Koala, Penguin, Falcon, Hedgehog, Deer, Squirrel, Robin, Butterfly, Hummingbird, Lynx, Seal, Crane, Gecko, Sparrow

**Excluded animals (no fat/negative connotations):** pig, hippo, cow, whale, walrus, manatee, bear, sloth

Combined as `"#{adjective} #{animal}"` — e.g., "Happy Otter", "Brave Falcon", "Sunny Penguin".

Implemented as a class method on User (`User.generate_fun_name`) called during the `after_create_account` hook: `User.create!(account_id: account_id, display_name: User.generate_fun_name)`.

## Layout

Onboarding steps use the existing `authentication` layout — centered, max-w-sm, Tally wordmark at top. The dot indicators render inside each step's view, below where the wordmark appears in the layout.

## Flash Messages

All flash messages in `config/locales/en.yml`:

```yaml
en:
  flash:
    onboarding_complete: "You're all set! Start tracking your nutrition."
```

The `finish` action sets this notice. The `skip` action does not set a flash (silent redirect).

## Testing

### Model tests
- `User.generate_fun_name` returns a string matching "Adjective Animal" pattern
- Generated names only contain allowed animals

### Controller tests (test/controllers/onboarding_controller_test.rb)
- Step 1 renders when not onboarded
- Step 1 redirects to root when already onboarded
- update_step1 saves display name and redirects to step2
- update_step2 saves calorie target and redirects to step3
- finish saves macro targets, sets onboarded_at, redirects to root
- skip sets onboarded_at without changing other fields, redirects to root
- All steps require authentication (redirect when logged out)

### Integration test
- `before_action` redirect: authenticated user with nil onboarded_at is redirected to step1
- `before_action` does not redirect when onboarded_at is set
- Full wizard flow: step1 → step2 → step3 → finish → lands on root without redirect loop

### System tests — Capybara (test/system/onboarding_test.rb)
- Step 1: page shows "Welcome to Tally!", displays pre-filled fun name, can change name and continue
- Step 2: page shows "Daily Calorie Target", slider and number input are present and synced, can adjust and continue
- Step 3: page shows "Macro Targets", all 4 sliders present, fiber is under "Additional health target" section, can adjust and finish
- Skip: clicking "Skip and use defaults" on any step completes onboarding with defaults intact
- Back navigation: Back button on step 2 returns to step 1, Back on step 3 returns to step 2
- Full flow end-to-end: complete all 3 steps, verify user record is updated and onboarded_at is set

## Gems

- `faker` gem (development/test group) — not needed. Using custom curated arrays instead for full control over tone and appropriateness.

No new gems required.

## Out of Scope

- Smart macro calculator linking macros to calorie total (Ticket 36)
- Biometrics-based suggestions (Ticket 36)
- Animation/transitions between steps
- Progress persistence across sessions (if user abandons mid-wizard, they restart)
