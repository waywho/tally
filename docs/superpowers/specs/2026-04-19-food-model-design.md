# Food Model — Design Spec

## Goal

Create the `Food` model and schema that serves as the single search target for all food data in Tally — imported from Open Food Facts, USDA, or created by users.

## Architecture

A single `foods` table stores all food data regardless of source. Nutritional values are stored per 100 grams (industry standard matching both OFF and USDA data formats). Per-serving values are calculated at read time using the `serving_size` column. Full-text search uses Postgres-native `tsvector` + `pg_trgm` — no external search service.

## Data Model

### `foods` table

All nutritional values are stored per 100 grams.

| Column | Type | Default | Notes |
|---|---|---|---|
| `name` | string(255) | not null | Food name |
| `brand` | string | nil | Brand/manufacturer |
| `barcode` | string | nil | EAN/UPC code |
| `serving_size` | decimal(8,2) | nil | Grams per one serving |
| `serving_label` | string | nil | Human-readable label, e.g. "1 cup", "1 slice" |
| `calories` | decimal(8,2) | not null | kcal per 100g |
| `protein` | decimal(8,2) | not null | grams per 100g |
| `carbs` | decimal(8,2) | not null | grams per 100g |
| `fat` | decimal(8,2) | not null | grams per 100g |
| `fiber` | decimal(8,2) | not null, default 0 | grams per 100g |
| `source` | integer | not null | enum: off (0), usda (1), user (2) |
| `external_id` | string | nil | Source-specific ID (OFF barcode, USDA FDC ID) |
| `creator_id` | bigint, FK | nil | References users, only set for source: :user |
| `verified_at` | datetime | nil | When nutritional data was last verified/updated |
| `searchable` | tsvector | generated | Auto-generated from name + brand for full-text search |
| `timestamps` | | | created_at, updated_at |

### Indexes

- `barcode` — B-tree index for direct barcode lookups
- `(source, external_id)` — unique composite index for deduplication on import (where external_id is not null)
- `searchable` — GIN index for full-text search via tsvector
- `name` — GIN trigram index via `pg_trgm` for fuzzy/partial matching
- `creator_id` — B-tree index for querying a user's custom foods

### Postgres Extensions

Enable `pg_trgm` extension in the migration for trigram-based fuzzy search.

### Generated tsvector column

The `searchable` column is a Postgres generated column that combines `name` and `brand` into a tsvector:

```sql
searchable tsvector GENERATED ALWAYS AS (
  to_tsvector('english', coalesce(name, '') || ' ' || coalesce(brand, ''))
) STORED
```

This auto-updates when `name` or `brand` changes — no application-level trigger needed.

## Model

```ruby
class Food < ApplicationRecord
  # All nutritional values are stored per 100 grams.

  belongs_to :creator, class_name: "User", optional: true

  enum :source, { off: 0, usda: 1, user: 2 }

  validates :name, presence: true, length: { maximum: 255 }
  validates :calories, :protein, :carbs, :fat,
    presence: true, numericality: { greater_than_or_equal_to: 0 }
  validates :fiber, numericality: { greater_than_or_equal_to: 0 }
  validates :source, presence: true
  validates :external_id, uniqueness: { scope: :source }, allow_nil: true
  validate :creator_required_for_user_source

  private

  def creator_required_for_user_source
    if user? && creator_id.nil?
      errors.add(:creator_id, "is required for user-created foods")
    end
  end
end
```

### Associations

```ruby
# app/models/user.rb (addition)
has_many :created_foods, class_name: "Food", foreign_key: :creator_id, dependent: :destroy
```

### Helper methods (for future tickets)

These will be added when needed but noted here for design awareness:

- `calories_per_serving` → `calories * serving_size / 100` (Ticket 12)
- `Food.search(query)` → combined tsvector + trigram search (Ticket 12)

## Testing

### Model tests (test/models/food_test.rb)
- Factory is valid
- Validates presence of name, calories, protein, carbs, fat, source
- Validates numericality >= 0 for all nutritional columns
- Validates name max length (255)
- Validates uniqueness of external_id scoped to source
- Allows duplicate nil external_ids (multiple user foods)
- Validates creator_id required when source is :user
- Does not require creator_id when source is :off or :usda
- Tests source enum (off?, usda?, user?)
- Tests association: creator (belongs_to User)
- Tests association: User has_many created_foods

### Factory (test/factories/foods.rb)
- Default factory for OFF-sourced food with sensible nutritional values
- `:usda` trait
- `:user_created` trait with creator association

## Out of Scope

- Sugar column (future ticket)
- Food search endpoint and UI (Ticket 12)
- USDA importer (Ticket 10)
- OFF sync (Ticket 11)
- Custom food CRUD (Ticket 13)
- Barcode lookup (Ticket 14)
