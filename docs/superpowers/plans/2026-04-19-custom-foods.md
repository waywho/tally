# Custom Foods Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Allow users to create, edit, and delete their own custom foods, with search results scoped so users only see their own custom foods.

**Architecture:** Extend `FoodsController` with CRUD actions (`new`, `create`, `edit`, `update`, `destroy`). Update `Food.search` to accept a `user:` parameter for visibility scoping. Add a form partial and "Create your own" link on the search page.

**Tech Stack:** Rails 8.1, Haml, Tailwind CSS, Minitest, FactoryBot

---

## File Structure

| Action | File | Responsibility |
|--------|------|----------------|
| Modify | `app/models/food.rb` | Add `user:` param to `Food.search` |
| Modify | `app/services/food_search.rb` | Pass `user:` through to `Food.search` |
| Modify | `app/controllers/foods_controller.rb` | Add CRUD actions, pass `current_user` to search |
| Modify | `config/routes.rb` | Expand foods resource |
| Create | `app/views/foods/_form.html.haml` | Shared new/edit form partial |
| Create | `app/views/foods/new.html.haml` | New food page |
| Create | `app/views/foods/edit.html.haml` | Edit food page |
| Modify | `app/views/foods/_results.html.haml` | Add "Create your own" link |
| Modify | `test/models/food_search_scope_test.rb` | Add user scoping tests |
| Modify | `test/services/food_search_test.rb` | Add user passthrough test |
| Modify | `test/controllers/foods_controller_test.rb` | Add CRUD tests |

---

### Task 1: Add user scoping to Food.search

**Files:**
- Modify: `app/models/food.rb`
- Modify: `test/models/food_search_scope_test.rb`

- [ ] **Step 1: Write the failing tests**

Add these tests to `test/models/food_search_scope_test.rb`:

```ruby
  test "search with user includes that user's custom foods" do
    user = create(:user)
    custom = create(:food, name: "Chicken custom", source: :user, external_id: nil, creator: user)

    results = Food.search("chicken", user: user)

    assert_includes results, custom
    assert_includes results, @chicken
  end

  test "search with user excludes other users' custom foods" do
    other_user = create(:user)
    other_custom = create(:food, name: "Chicken other", source: :user, external_id: nil, creator: other_user)

    user = create(:user)
    results = Food.search("chicken", user: user)

    assert_not_includes results, other_custom
    assert_includes results, @chicken
  end

  test "search without user excludes all user-created foods" do
    results = Food.search("chicken")

    assert_includes results, @chicken
    assert_not_includes results, @chicken_stir
  end
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `bin/rails test test/models/food_search_scope_test.rb`
Expected: The "excludes other users" and "excludes all user-created" tests will fail because the current `Food.search` doesn't filter by user.

- [ ] **Step 3: Update the implementation**

Edit `app/models/food.rb` — replace the `search` method:

```ruby
  def self.search(query, limit: 20, user: nil)
    return none if query.blank?

    scope = where("searchable @@ plainto_tsquery('english', ?)", query)
      .or(where("name ILIKE ?", "%#{sanitize_sql_like(query)}%"))

    if user
      scope = scope.where.not(source: :user).or(scope.where(source: :user, creator_id: user.id))
    else
      scope = scope.where.not(source: :user)
    end

    scope
      .order(Arel.sql("ts_rank(searchable, plainto_tsquery('english', #{connection.quote(query)})) DESC"), :name)
      .limit(limit)
  end
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `bin/rails test test/models/food_search_scope_test.rb`
Expected: 8 tests, 0 failures.

- [ ] **Step 5: Commit**

```bash
git add app/models/food.rb test/models/food_search_scope_test.rb
git commit -m "feat: add user scoping to Food.search"
```

---

### Task 2: Pass user through FoodSearch service

**Files:**
- Modify: `app/services/food_search.rb`
- Modify: `test/services/food_search_test.rb`
- Modify: `app/controllers/foods_controller.rb`

- [ ] **Step 1: Write the failing test**

Add to `test/services/food_search_test.rb`:

```ruby
  test "passes user to Food.search for visibility scoping" do
    user = create(:user)
    custom = create(:food, name: "Chicken custom", source: :user, external_id: nil, creator: user)
    5.times { |i| create(:food, name: "Chicken item #{i}", source: :off, external_id: "scope-#{i}") }

    results = FoodSearch.call("chicken", user: user)

    assert results.any? { |r| r.is_a?(Food) && r.user? && r.creator_id == user.id }
  end

  test "excludes other users custom foods from results" do
    other_user = create(:user)
    create(:food, name: "Chicken other", source: :user, external_id: nil, creator: other_user)
    5.times { |i| create(:food, name: "Chicken item #{i}", source: :off, external_id: "excl-#{i}") }

    user = create(:user)
    results = FoodSearch.call("chicken", user: user)

    assert_not results.any? { |r| r.is_a?(Food) && r.user? && r.creator_id == other_user.id }
  end
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `bin/rails test test/services/food_search_test.rb`
Expected: FAIL — `FoodSearch.call` doesn't accept `user:` yet.

- [ ] **Step 3: Update FoodSearch service**

Edit `app/services/food_search.rb` — add `user:` parameter:

```ruby
class FoodSearch
  LOCAL_THRESHOLD = 5

  def self.call(query, limit: 20, user: nil, off_client: nil, usda_client: nil)
    new(query, limit: limit, user: user, off_client: off_client, usda_client: usda_client).call
  end

  def initialize(query, limit: 20, user: nil, off_client: nil, usda_client: nil)
    @query = query
    @limit = limit
    @user = user
    @injected_off_client = off_client
    @injected_usda_client = usda_client
  end

  def call
    return [] if @query.blank?

    local_results = Food.search(@query, limit: @limit, user: @user)

    if local_results.size >= LOCAL_THRESHOLD
      return local_results.first(@limit)
    end

    external_results = fetch_external_results(local_results)
    merged = merge_results(local_results, external_results)
    merged.first(@limit)
  end

  private

  def off_client
    @off_client ||= @injected_off_client || Off::Client.new
  end

  def usda_client
    @usda_client ||= @injected_usda_client || Usda::Client.new
  end

  def fetch_external_results(local_results)
    results = []

    # OFF: persist immediately (aggressive caching)
    begin
      off_results = off_client.search(@query, page: 1, per_page: 20)
      off_results.each do |off_result|
        food = off_client.persist(off_result)
        results << food
      end
    rescue Off::Error => e
      Rails.logger.warn("OFF search failed: #{e.message}")
    end

    # USDA: return transient structs (persist on interaction)
    begin
      usda_results = usda_client.search(@query, page: 1, per_page: 20)
      results.concat(usda_results)
    rescue Usda::Error => e
      Rails.logger.warn("USDA search failed: #{e.message}")
    end

    results
  end

  def merge_results(local_results, external_results)
    local_ids = local_results.map { |f| [f.source, f.external_id] }.to_set

    deduped_external = external_results.reject do |result|
      case result
      when Food
        local_ids.include?([result.source, result.external_id])
      when Usda::FoodResult
        local_ids.include?(["usda", result.fdc_id])
      else
        false
      end
    end

    local_results + deduped_external
  end
end
```

- [ ] **Step 4: Update FoodsController to pass current_user**

Edit `app/controllers/foods_controller.rb` — update the `index` action:

```ruby
class FoodsController < ApplicationController
  before_action :require_authentication

  def index
    @query = params[:q].to_s.strip
    @results = if @query.length >= 3
      FoodSearch.call(@query, user: current_user)
    else
      []
    end
  end
end
```

- [ ] **Step 5: Run tests to verify they pass**

Run: `bin/rails test test/services/food_search_test.rb test/controllers/foods_controller_test.rb`
Expected: All pass.

- [ ] **Step 6: Commit**

```bash
git add app/services/food_search.rb app/controllers/foods_controller.rb test/services/food_search_test.rb
git commit -m "feat: pass user through FoodSearch for visibility scoping"
```

---

### Task 3: Add CRUD actions to FoodsController

**Files:**
- Modify: `config/routes.rb`
- Modify: `app/controllers/foods_controller.rb`
- Modify: `test/controllers/foods_controller_test.rb`

- [ ] **Step 1: Update routes**

Edit `config/routes.rb` — change the foods resource:

```ruby
  resources :foods, only: [:index, :new, :create, :edit, :update, :destroy]
```

- [ ] **Step 2: Write the failing tests**

Add to `test/controllers/foods_controller_test.rb`:

```ruby
  # New
  test "new renders form when authenticated" do
    login(@account)
    get new_food_path
    assert_response :success
    assert_select "form[action='#{foods_path}']"
    assert_select "input[name='food[name]']"
    assert_select "input[name='food[calories]']"
  end

  test "new redirects when not authenticated" do
    get new_food_path
    assert_response :redirect
  end

  test "new pre-fills name from query param" do
    login(@account)
    get new_food_path(name: "My special food")
    assert_response :success
    assert_select "input[name='food[name]'][value='My special food']"
  end

  # Create
  test "create saves food with source user and creator" do
    login(@account)

    assert_difference "Food.count", 1 do
      post foods_path, params: {
        food: {
          name: "Homemade pasta",
          calories: 200,
          protein: 8,
          carbs: 35,
          fat: 4,
          fiber: 2,
          brand: "Mom's kitchen",
          barcode: "",
          serving_size: 150,
          serving_label: "1 plate"
        }
      }
    end

    food = Food.last
    assert food.user?
    assert_equal @user.id, food.creator_id
    assert_equal "Homemade pasta", food.name
    assert_redirected_to foods_path(q: "Homemade pasta")
  end

  test "create with invalid params re-renders form" do
    login(@account)

    assert_no_difference "Food.count" do
      post foods_path, params: {
        food: { name: "", calories: -1 }
      }
    end

    assert_response :unprocessable_entity
    assert_select "p.field-error"
  end

  # Edit
  test "edit renders form for creator" do
    login(@account)
    food = create(:food, :user_created, creator: @user, name: "My food")

    get edit_food_path(food)
    assert_response :success
    assert_select "input[name='food[name]'][value='My food']"
  end

  test "edit returns 404 for non-creator" do
    other_user = create(:user)
    food = create(:food, :user_created, creator: other_user, name: "Other food")

    login(@account)
    assert_raises(ActiveRecord::RecordNotFound) do
      get edit_food_path(food)
    end
  end

  # Update
  test "update saves changes for creator" do
    login(@account)
    food = create(:food, :user_created, creator: @user, name: "Old name")

    patch food_path(food), params: { food: { name: "New name" } }

    assert_redirected_to foods_path(q: "New name")
    assert_equal "New name", food.reload.name
  end

  test "update returns 404 for non-creator" do
    other_user = create(:user)
    food = create(:food, :user_created, creator: other_user)

    login(@account)
    assert_raises(ActiveRecord::RecordNotFound) do
      patch food_path(food), params: { food: { name: "Hacked" } }
    end
  end

  # Destroy
  test "destroy removes food for creator" do
    login(@account)
    food = create(:food, :user_created, creator: @user)

    assert_difference "Food.count", -1 do
      delete food_path(food)
    end

    assert_redirected_to foods_path
    assert_equal "Food deleted.", flash[:notice]
  end

  test "destroy returns 404 for non-creator" do
    other_user = create(:user)
    food = create(:food, :user_created, creator: other_user)

    login(@account)
    assert_raises(ActiveRecord::RecordNotFound) do
      delete food_path(food)
    end
  end
```

- [ ] **Step 3: Run tests to verify they fail**

Run: `bin/rails test test/controllers/foods_controller_test.rb`
Expected: FAIL — actions not defined.

- [ ] **Step 4: Write the controller**

Replace `app/controllers/foods_controller.rb`:

```ruby
class FoodsController < ApplicationController
  before_action :require_authentication
  before_action :set_food, only: [:edit, :update, :destroy]

  def index
    @query = params[:q].to_s.strip
    @results = if @query.length >= 3
      FoodSearch.call(@query, user: current_user)
    else
      []
    end
  end

  def new
    @food = Food.new(name: params[:name])
  end

  def create
    @food = current_user.created_foods.build(food_params)
    @food.source = :user

    if @food.save
      redirect_to foods_path(q: @food.name), notice: t("flash.food_created")
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit
  end

  def update
    if @food.update(food_params)
      redirect_to foods_path(q: @food.name), notice: t("flash.food_updated")
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @food.destroy!
    redirect_to foods_path, notice: t("flash.food_deleted")
  end

  private

  def set_food
    @food = current_user.created_foods.find(params[:id])
  end

  def food_params
    params.require(:food).permit(:name, :brand, :calories, :protein, :carbs, :fat, :fiber, :barcode, :serving_size, :serving_label)
  end
end
```

- [ ] **Step 5: Add flash messages to locale**

Edit `config/locales/en.yml` — add under `flash:`:

```yaml
    food_created: "Food created."
    food_updated: "Food updated."
    food_deleted: "Food deleted."
```

- [ ] **Step 6: Run tests to verify they pass**

Run: `bin/rails test test/controllers/foods_controller_test.rb`
Expected: All pass (but views don't exist yet — `new` and `edit` tests may fail). If they fail due to missing templates, proceed to Task 4 and come back.

- [ ] **Step 7: Commit**

```bash
git add app/controllers/foods_controller.rb config/routes.rb config/locales/en.yml test/controllers/foods_controller_test.rb
git commit -m "feat: add CRUD actions to FoodsController"
```

---

### Task 4: Create form views

**Files:**
- Create: `app/views/foods/_form.html.haml`
- Create: `app/views/foods/new.html.haml`
- Create: `app/views/foods/edit.html.haml`

- [ ] **Step 1: Create the shared form partial**

Create `app/views/foods/_form.html.haml`:

```haml
= form_with model: food, url: url do |f|
  = render CardComponent.new(class: "p-6 mb-6") do
    %h2.text-lg.font-semibold.text-text.mb-4 Food Details
    .mb-4
      = f.label :name, class: "label"
      = f.text_field :name, class: "input", placeholder: "e.g. Homemade pasta", required: true, maxlength: 255
      - if food.errors[:name].any?
        %p.field-error= food.errors[:name].first
    .mb-4
      = f.label :brand, class: "label"
      = f.text_field :brand, class: "input", placeholder: "Optional"

  = render CardComponent.new(class: "p-6 mb-6") do
    %h2.text-lg.font-semibold.text-text.mb-4 Nutrition (per 100g)
    .mb-4
      = f.label :calories, "Calories (kcal)", class: "label"
      = f.number_field :calories, class: "input", min: 0, step: "any", required: true
      - if food.errors[:calories].any?
        %p.field-error= food.errors[:calories].first
    .grid.grid-cols-2.gap-4
      .mb-4
        = f.label :protein, "Protein (g)", class: "label"
        = f.number_field :protein, class: "input", min: 0, step: "any", required: true
        - if food.errors[:protein].any?
          %p.field-error= food.errors[:protein].first
      .mb-4
        = f.label :carbs, "Carbs (g)", class: "label"
        = f.number_field :carbs, class: "input", min: 0, step: "any", required: true
        - if food.errors[:carbs].any?
          %p.field-error= food.errors[:carbs].first
      .mb-4
        = f.label :fat, "Fat (g)", class: "label"
        = f.number_field :fat, class: "input", min: 0, step: "any", required: true
        - if food.errors[:fat].any?
          %p.field-error= food.errors[:fat].first
      .mb-4
        = f.label :fiber, "Fiber (g)", class: "label"
        = f.number_field :fiber, class: "input", min: 0, step: "any", value: food.fiber || 0
        - if food.errors[:fiber].any?
          %p.field-error= food.errors[:fiber].first

  = render CardComponent.new(class: "p-6 mb-6") do
    %h2.text-lg.font-semibold.text-text.mb-4 Serving Info (optional)
    .grid.grid-cols-2.gap-4
      .mb-4
        = f.label :serving_size, "Serving size (g)", class: "label"
        = f.number_field :serving_size, class: "input", min: 0, step: "any"
      .mb-4
        = f.label :serving_label, "Serving label", class: "label"
        = f.text_field :serving_label, class: "input", placeholder: "e.g. 1 cup"
    .mb-4
      = f.label :barcode, class: "label"
      = f.text_field :barcode, class: "input", placeholder: "Optional"

  = render ButtonComponent.new(label: submit_label, tag: :button, type: "submit", class: "w-full")
```

- [ ] **Step 2: Create the new view**

Create `app/views/foods/new.html.haml`:

```haml
- @page_title = "Create Food"

%h1.text-xl.font-bold.mb-4 Create Food

= render "form", food: @food, url: foods_path, submit_label: "Create Food"

%p.text-center.text-sm.text-text-secondary.mt-4
  = link_to "Back to search", foods_path, class: "text-primary"
```

- [ ] **Step 3: Create the edit view**

Create `app/views/foods/edit.html.haml`:

```haml
- @page_title = "Edit Food"

%h1.text-xl.font-bold.mb-4 Edit Food

= render "form", food: @food, url: food_path(@food), submit_label: "Save Changes"

%p.text-center.text-sm.text-text-secondary.mt-4
  = link_to "Back to search", foods_path, class: "text-primary"
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `bin/rails test test/controllers/foods_controller_test.rb`
Expected: All 16 tests pass.

- [ ] **Step 5: Run full test suite**

Run: `bin/rails test`
Expected: All tests pass.

- [ ] **Step 6: Commit**

```bash
git add app/views/foods/_form.html.haml app/views/foods/new.html.haml app/views/foods/edit.html.haml
git commit -m "feat: add new/edit views for custom foods"
```

---

### Task 5: Add "Create your own" link to search results

**Files:**
- Modify: `app/views/foods/_results.html.haml`

- [ ] **Step 1: Add the link**

Add at the bottom of `app/views/foods/_results.html.haml`:

```haml
- if @query.present? && @query.length >= 3
  .text-center.py-4.border-t.border-border.mt-2
    %p.text-sm.text-text-secondary
      Can't find it?
      = link_to "Create your own", new_food_path(name: @query), class: "text-primary font-medium"
```

- [ ] **Step 2: Verify the link renders**

Run: `bin/rails test test/controllers/foods_controller_test.rb -n "test_index_returns_results_for_valid_query"`
Expected: Pass.

- [ ] **Step 3: Commit**

```bash
git add app/views/foods/_results.html.haml
git commit -m "feat: add 'Create your own' link to search results"
```

---

### Task 6: Add edit/delete links for user-created foods in results

**Files:**
- Modify: `app/views/foods/_results.html.haml`

Each user-created food in the search results should show small edit/delete links so the creator can manage their foods inline.

- [ ] **Step 1: Add edit/delete links to user food rows**

In `app/views/foods/_results.html.haml`, after the macro line inside the result loop, add a conditional for user-created foods. Replace the entire result block with:

Find the line:
```haml
    .flex.flex-wrap.gap-2.text-xs.text-text-secondary{ class: "mt-1.5" }
```

After the closing of the macro flex div (after `%span.ml-auto{ style: "font-size: 11px;" } per 100g`), add:

```haml
    - if result.is_a?(Food) && result.user? && result.creator_id == current_user&.id
      .flex.gap-3.mt-1.text-xs
        = link_to "Edit", edit_food_path(result), class: "text-primary"
        = link_to "Delete", food_path(result), data: { turbo_method: :delete, turbo_confirm: "Delete #{result.name}?" }, class: "text-danger"
```

- [ ] **Step 2: Run the full test suite**

Run: `bin/rails test`
Expected: All tests pass.

- [ ] **Step 3: Commit**

```bash
git add app/views/foods/_results.html.haml
git commit -m "feat: add edit/delete links for user-created foods in search results"
```
