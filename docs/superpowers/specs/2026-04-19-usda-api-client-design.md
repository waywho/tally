# USDA FDC API Client — Design Spec

## Goal

Build a service class that wraps the USDA FoodData Central API, enabling on-demand food search and lookup. Foods are returned as plain structs and only persisted to the `foods` table when a user selects one (cache on interaction).

## Architecture

A `Usda::Client` service class makes HTTP requests to the USDA FDC REST API using the `rest-client` gem. Responses are normalized into `Usda::FoodResult` structs. A `persist` method converts a struct into a `Food` ActiveRecord record, deduped by `(source: :usda, external_id: fdc_id)`.

This ticket builds the service layer only. The search UI (Ticket 12) and barcode lookup (Ticket 14) will call this client.

## API Details

**Base URL:** `https://api.nal.usda.gov/fdc/v1`

**Authentication:** API key passed as `api_key` query parameter. Stored as `USDA_API_KEY` environment variable.

**Rate limit:** 1,000 requests/hour on the free tier. No throttling in MVP — handle 429 responses gracefully with a clear error.

### Endpoints

**Search:** `POST /fdc/v1/foods/search`
```json
{
  "query": "chicken breast",
  "dataType": ["Foundation", "SR Legacy"],
  "pageSize": 20,
  "pageNumber": 1
}
```

**Single food:** `GET /fdc/v1/food/{fdcId}`

### Nutrient ID Mapping

The API returns nutrients as an array with numeric IDs. We extract:

| Nutrient ID | Maps to | Description |
|---|---|---|
| 1008 | `calories` | Energy (kcal) |
| 1003 | `protein` | Protein |
| 1005 | `carbs` | Carbohydrate, by difference |
| 1004 | `fat` | Total lipid (fat) |
| 1079 | `fiber` | Fiber, total dietary |

All values from the API are per 100g, matching our Food model convention.

## Service Classes

### `Usda::Client`

```ruby
# app/services/usda/client.rb
module Usda
  class Client
    BASE_URL = "https://api.nal.usda.gov/fdc/v1"
    DATA_TYPES = ["Foundation", "SR Legacy"].freeze

    def initialize(api_key: ENV.fetch("USDA_API_KEY"))
      @api_key = api_key
    end

    def search(query, page: 1, per_page: 20)
      # POST /foods/search with dataType filter
      # Returns array of Usda::FoodResult
    end

    def fetch(fdc_id)
      # GET /food/{fdcId}
      # Returns a single Usda::FoodResult
    end

    def persist(food_result)
      # Find or create a Food record by (source: :usda, external_id: fdc_id)
      # Returns the Food ActiveRecord object
    end
  end
end
```

### `Usda::FoodResult`

A plain Ruby Struct that normalizes USDA API responses:

```ruby
# app/services/usda/food_result.rb
module Usda
  FoodResult = Struct.new(
    :fdc_id, :name, :brand,
    :calories, :protein, :carbs, :fat, :fiber,
    :serving_size, :serving_label,
    keyword_init: true
  )
end
```

### `Usda::NutrientMapper`

Extracts nutrient values from the API's `foodNutrients` array:

```ruby
# app/services/usda/nutrient_mapper.rb
module Usda
  class NutrientMapper
    NUTRIENT_IDS = {
      1008 => :calories,
      1003 => :protein,
      1005 => :carbs,
      1004 => :fat,
      1079 => :fiber
    }.freeze

    def self.extract(food_nutrients)
      # Returns a hash { calories: 165.0, protein: 31.0, ... }
      # Missing nutrients default to 0.0
    end
  end
end
```

## Error Handling

- **Missing API key:** `Usda::Client.new` raises `Usda::ConfigError` if `USDA_API_KEY` is not set.
- **API errors (4xx/5xx):** Catch `RestClient::Exception`, wrap in `Usda::ApiError` with the status code and message.
- **Rate limited (429):** Raise `Usda::RateLimitError` (subclass of `Usda::ApiError`).
- **Network errors:** Catch `RestClient::Exceptions::Timeout` and connection errors, wrap in `Usda::ApiError`.

All custom errors inherit from `Usda::Error` base class.

## Gems

- `rest-client` — HTTP client for API requests
- `webmock` (test group) — stub HTTP requests in tests

## Testing

### Unit tests (test/services/usda/)

**`test/services/usda/nutrient_mapper_test.rb`**
- Extracts all 5 nutrients from a sample `foodNutrients` array
- Returns 0.0 for missing nutrients
- Ignores unrecognized nutrient IDs

**`test/services/usda/client_test.rb`**
- `search` sends correct POST request with query and dataType filter
- `search` returns array of `Usda::FoodResult` structs
- `search` handles empty results
- `fetch` sends correct GET request with fdc_id
- `fetch` returns a `Usda::FoodResult` struct
- `persist` creates a new Food record from a FoodResult
- `persist` finds existing Food by (source: :usda, external_id) instead of duplicating
- `persist` updates existing Food's nutritional data on re-persist
- Raises `Usda::ConfigError` when API key is missing
- Raises `Usda::ApiError` on 500 response
- Raises `Usda::RateLimitError` on 429 response

All HTTP calls stubbed with `webmock` using fixture JSON responses.

**`test/services/usda/food_result_test.rb`**
- Struct has all expected attributes
- Keyword initialization works

## File Structure

```
app/services/usda/
  client.rb          — API client (search, fetch, persist)
  food_result.rb     — Plain struct for normalized results
  nutrient_mapper.rb — Extracts nutrients from API response
  error.rb           — Custom error classes

test/services/usda/
  client_test.rb
  nutrient_mapper_test.rb
  food_result_test.rb

test/fixtures/files/usda/
  search_response.json    — Sample search API response
  food_response.json      — Sample single food API response
```

## Out of Scope

- Search UI / endpoint (Ticket 12)
- Barcode lookup (Ticket 14)
- Open Food Facts integration (Ticket 11)
- Rate limit throttling / queueing
- Pagination beyond first page in MVP (Ticket 12 can add "load more")
