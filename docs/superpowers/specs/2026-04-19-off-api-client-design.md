# Open Food Facts API Client — Design Spec

## Goal

Build a thin wrapper service around the `openfoodfacts` Ruby gem that provides search-by-name and fetch-by-barcode capabilities, with persist-on-interaction caching into the `foods` table. This replaces the original Ticket 11 (bulk daily sync) and absorbs Ticket 14 (barcode lookup-on-miss).

## Architecture

On-demand API client following the same pattern as `Usda::Client`. The official `openfoodfacts` gem handles HTTP transport; our wrapper handles nutrient mapping, result normalization, and persistence.

```
Off::Client
  ├── search(query, page:, per_page:) → Off::FoodResult[]
  ├── fetch(barcode)                  → Off::FoodResult
  └── persist(food_result)            → Food (ActiveRecord)

Off::FoodResult (Struct)
Off::NutrientMapper
Off::Error hierarchy
```

## Components

### Off::Client

**File:** `app/services/off/client.rb`

Three public methods:

- `search(query, page: 1, per_page: 20)` — Calls `Openfoodfacts::Product.search(query, locale: 'world', page_size: per_page)`. Maps each result through `NutrientMapper` into `FoodResult` structs. Returns an array.

- `fetch(barcode)` — Calls `Openfoodfacts::Product.get(barcode, locale: 'world')`. Raises `ProductNotFoundError` if the product is nil or has no product name. Returns a single `FoodResult`.

- `persist(food_result)` — `Food.find_or_initialize_by(source: :off, external_id: food_result.barcode)`, updates nutritional fields, saves. Returns the `Food` record.

All searches use locale `world` (no country scoping for MVP).

No rate limiting logic for MVP. OFF allows 10 req/min for search, 100 req/min for product reads. At current scale this won't be hit.

### Off::FoodResult

**File:** `app/services/off/food_result.rb`

```ruby
FoodResult = Struct.new(
  :barcode, :name, :brand,
  :calories, :protein, :carbs, :fat, :fiber,
  :serving_size, :serving_label,
  keyword_init: true
)
```

### Off::NutrientMapper

**File:** `app/services/off/nutrient_mapper.rb`

Maps from the OFF gem's `nutriments.to_hash` field names to our model fields:

| OFF field | Our field |
|---|---|
| `energy-kcal_100g` | `calories` |
| `proteins_100g` | `protein` |
| `carbohydrates_100g` | `carbs` |
| `fat_100g` | `fat` |
| `fiber_100g` | `fiber` |

All values default to `0.0` if missing or nil.

Input: a hash from `product.nutriments.to_hash`
Output: `{ calories:, protein:, carbs:, fat:, fiber: }`

### Off::Error

**File:** `app/services/off/error.rb`

```
Off::Error (base)
  ├── Off::ApiError          — gem raises an exception (network error, HTTP error)
  └── Off::ProductNotFoundError — barcode lookup returns nil/empty product
```

## Key Decisions

- **Per 100g storage** — OFF nutriments already use `*_100g` fields, matching our Food model convention.
- **external_id = barcode** — OFF products are identified by barcode (`code` field). This is stored as `external_id` with `source: :off`.
- **No API key** — OFF requires only a User-Agent header, which the gem handles.
- **Locale: world** — All searches hit the global database. Country-scoped filtering deferred.
- **Cache on interaction** — Products are persisted to our `foods` table when the user interacts with them (via `persist`), not on search.
- **Gem handles HTTP** — No direct `rest-client` usage. The `openfoodfacts` gem manages all API communication.

## Dependencies

- `openfoodfacts` gem (add to Gemfile)
- Existing `Food` model with `source: :off` enum and `(source, external_id)` unique index

## Testing

- **Stub the gem, not HTTP** — Since the gem handles transport, stub `Openfoodfacts::Product.search` and `Openfoodfacts::Product.get` directly instead of using webmock.
- **NutrientMapper** — Unit tests with realistic OFF nutriment hashes, including missing fields and edge cases (nil values, zero values).
- **Client#search** — Stub gem search, verify mapping to FoodResult array.
- **Client#fetch** — Stub gem get, verify FoodResult. Test nil product raises `ProductNotFoundError`.
- **Client#persist** — Test creates new Food, test updates existing Food (idempotent upsert), verify all nutritional fields mapped correctly.
- **Error handling** — Test that gem exceptions are wrapped in `Off::ApiError`.

## Out of Scope

- Country/locale-scoped search (future enhancement)
- Rate limiting logic (YAGNI at current scale)
- Product images or categories
- Sugar, sodium, or other nutrients beyond the core 5
- Search UI (Ticket 12)
- Controller/routes (Ticket 12)
