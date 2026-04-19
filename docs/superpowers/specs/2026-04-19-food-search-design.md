# Food Search Endpoint + UI — Design Spec

## Goal

Build a food search feature that lets users find foods by name, querying the local database first and automatically falling back to USDA and Open Food Facts APIs when local results are sparse. Results render in a Turbo Frame as detailed rows with calories and full macro breakdown.

## Architecture

Local-first search with auto-fallback to external APIs. A `FoodSearch` service orchestrates multi-source queries. A Stimulus controller handles debouncing and Turbo Frame submission. Server renders all HTML — no client-side templating.

### Search Flow

1. User types query (min 3 characters, 300ms debounce)
2. Stimulus controller submits form → `GET /foods?q=chicken`
3. `FoodsController#index` delegates to `FoodSearch.call(query)`
4. `FoodSearch` queries local `foods` table using tsvector/trigram
5. If fewer than 5 local results, auto-queries USDA + OFF APIs in sequence
6. OFF results are persisted immediately (aggressive caching — OFF has strict rate limits: 10 req/min)
7. USDA results are returned as transient structs (persisted only when user selects one — Ticket 13/logging)
8. All results merged, deduped, capped at 20, rendered as Turbo Frame partial

### Caching Strategy

- **OFF results**: Persist on search (source has 10 req/min rate limit, aggressive caching reduces future API calls)
- **USDA results**: Persist on interaction only (1,000 req/hour, more generous limit)
- Over time, local DB fills up and fewer external API calls are needed

## Components

### FoodSearch Service

**File:** `app/services/food_search.rb`

Single public method: `FoodSearch.call(query, limit: 20)`

Returns a mixed array: local `Food` records + transient `Usda::FoodResult` structs. The caller can distinguish by type (`Food` vs `Usda::FoodResult`).

Logic:
1. Search local DB: `Food` table using PostgreSQL full-text search (tsvector) with trigram fallback for fuzzy matching. Limit to `limit` results.
2. If local results < 5:
   - Query `Off::Client.search(query)` — persist all results immediately via `Off::Client.persist`, then include the persisted `Food` records
   - Query `Usda::Client.search(query)` — return `FoodResult` structs without persisting
3. Deduplicate: if a USDA/OFF result matches an existing local food (same `source` + `external_id`), drop the external duplicate
4. Cap at `limit` (default 20)
5. If any external API raises an error, log it and continue with whatever results we have

### FoodsController

**File:** `app/controllers/foods_controller.rb`

CRUD controller — only `index` for now:

- `index` — requires authentication, reads `params[:q]`, delegates to `FoodSearch.call`, renders results partial in a Turbo Frame
- Returns empty state partial if query is blank or fewer than 3 characters
- Turbo Frame ID: `food_search_results`

### Routes

```ruby
resources :foods, only: [:index]
```

### Views

**`app/views/foods/index.html.haml`** — Full search page:
- Search input field inside a form targeting the Turbo Frame
- Turbo Frame `food_search_results` wrapping the results list
- Stimulus controller `search` on the form

**`app/views/foods/_results.html.haml`** — Results partial (rendered inside the Turbo Frame):
- Iterates over results, renders each as a result row
- Loading indicator (shown via Turbo Frame loading state)
- Empty state when no results found
- "Searching external databases..." indicator when applicable

**Result row layout** (per result):
- Top line: food name (left, truncated) + calories in bold (right)
- Second line: source badge (USDA green, OFF amber, You purple) + brand name
- Third line: `Protein 22.5g · Carbs 0g · Fat 2.6g · Fiber 0g` + "per 100g" aligned right

### Source Badge Colors

| Source | Background | Text |
|--------|-----------|------|
| USDA | `#F0FDF4` (green-50) | `#16A34A` (green-600) |
| OFF | `#FEF3C7` (amber-100) | `#D97706` (amber-600) |
| User | `#EDE9FE` (violet-100) | `#7C3AED` (violet-600) |

### Stimulus Controller

**File:** `app/javascript/controllers/search_controller.js`

Responsibilities:
- Debounce input by 300ms
- Minimum 3 characters before submitting
- Submit the form targeting the Turbo Frame
- Show/hide loading state

Targets: `input`, `form`

## Local Database Search

Uses PostgreSQL full-text search capabilities already set up on the `foods` table:

1. **Primary**: tsvector search on the `searchable` generated column (combines `name` + `brand`)
   - Query: `WHERE searchable @@ plainto_tsquery('english', ?)`
2. **Fallback**: trigram similarity on `name` column for fuzzy matching
   - Query: `WHERE name % ?` (trigram similarity operator)
   - Or: `WHERE name ILIKE ?` for simple prefix matching

Order results by relevance (tsvector rank) then by name.

## Dependencies

- Existing `Off::Client` and `Usda::Client` with `search` and `persist` methods
- Existing `Food` model with tsvector/trigram indexes
- Turbo Rails (already installed)
- Stimulus (already installed)

## Testing

### FoodSearch Service Tests (unit)

- Returns local results when 5+ exist
- Queries external APIs when fewer than 5 local results
- Persists OFF results immediately on search
- Does not persist USDA results on search
- Deduplicates results (same food from local DB + external API)
- Returns empty array for blank/nil queries
- Handles OFF API errors gracefully (continues with local + USDA)
- Handles USDA API errors gracefully (continues with local + OFF)
- Caps total results at 20

### FoodsController Tests (integration)

- `GET /foods?q=chicken` returns search results in Turbo Frame
- Requires authentication (redirects to login if not logged in)
- Returns empty state for queries shorter than 3 characters
- Returns empty state for blank query

### Stimulus Controller

Manual verification only — consistent with current project test approach.

## Out of Scope

- Food detail/show page (future)
- Custom food creation form (Ticket 13)
- Logging a food entry (Ticket 15+)
- Pagination of search results (20 cap is sufficient for MVP)
- Recent/frequent foods tabs (Ticket 22)
- Barcode scanning trigger (Ticket 27, iOS native)
