# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# This file is the source Rails uses to define your schema when running `bin/rails
# db:schema:load`. When creating a new database, `bin/rails db:schema:load` tends to
# be faster and is potentially less error prone than running all of your
# migrations from scratch. Old migrations may fail to apply correctly if those
# migrations use external dependencies or application code.
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema[8.1].define(version: 2026_04_20_221740) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "citext"
  enable_extension "pg_catalog.plpgsql"
  enable_extension "pg_trgm"

  create_table "account_login_change_keys", force: :cascade do |t|
    t.datetime "deadline", null: false
    t.string "key", null: false
    t.string "login", null: false
  end

  create_table "account_password_reset_keys", force: :cascade do |t|
    t.datetime "deadline", null: false
    t.datetime "email_last_sent", default: -> { "CURRENT_TIMESTAMP" }, null: false
    t.string "key", null: false
  end

  create_table "account_remember_keys", force: :cascade do |t|
    t.datetime "deadline", null: false
    t.string "key", null: false
  end

  create_table "account_verification_keys", force: :cascade do |t|
    t.datetime "email_last_sent", default: -> { "CURRENT_TIMESTAMP" }, null: false
    t.string "key", null: false
    t.datetime "requested_at", default: -> { "CURRENT_TIMESTAMP" }, null: false
  end

  create_table "accounts", force: :cascade do |t|
    t.citext "email", null: false
    t.string "password_hash"
    t.integer "status", default: 1, null: false
    t.index ["email"], name: "index_accounts_on_email", unique: true, where: "(status = ANY (ARRAY[1, 2]))"
    t.check_constraint "email ~ '^[^,;@ \r\n]+@[^,@; \r\n]+.[^,@; \r\n]+$'::citext", name: "valid_email"
  end

  create_table "food_log_entries", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.bigint "food_id", null: false
    t.date "logged_on", null: false
    t.integer "meal", null: false
    t.datetime "updated_at", null: false
    t.bigint "user_id", null: false
    t.decimal "weight", precision: 8, scale: 2, null: false
    t.index ["food_id"], name: "index_food_log_entries_on_food_id"
    t.index ["user_id", "food_id"], name: "index_food_log_entries_on_user_id_and_food_id"
    t.index ["user_id", "logged_on"], name: "index_food_log_entries_on_user_id_and_logged_on"
    t.index ["user_id"], name: "index_food_log_entries_on_user_id"
  end

  create_table "foods", force: :cascade do |t|
    t.string "barcode"
    t.string "brand"
    t.decimal "calories", precision: 8, scale: 2, null: false
    t.decimal "carbs", precision: 8, scale: 2, null: false
    t.datetime "created_at", null: false
    t.bigint "creator_id"
    t.string "external_id"
    t.decimal "fat", precision: 8, scale: 2, null: false
    t.decimal "fiber", precision: 8, scale: 2, default: "0.0", null: false
    t.string "name", limit: 255, null: false
    t.decimal "protein", precision: 8, scale: 2, null: false
    t.virtual "searchable", type: :tsvector, as: "to_tsvector('english'::regconfig, (((COALESCE(name, ''::character varying))::text || ' '::text) || (COALESCE(brand, ''::character varying))::text))", stored: true
    t.string "serving_label"
    t.decimal "serving_size", precision: 8, scale: 2
    t.integer "source", null: false
    t.datetime "updated_at", null: false
    t.datetime "verified_at"
    t.index ["barcode"], name: "index_foods_on_barcode"
    t.index ["creator_id"], name: "index_foods_on_creator_id"
    t.index ["name"], name: "index_foods_on_name_trigram", opclass: :gin_trgm_ops, using: :gin
    t.index ["searchable"], name: "index_foods_on_searchable", using: :gin
    t.index ["source", "external_id"], name: "index_foods_on_source_and_external_id", unique: true, where: "(external_id IS NOT NULL)"
  end

  create_table "meal_template_items", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.bigint "food_id", null: false
    t.bigint "meal_template_id", null: false
    t.datetime "updated_at", null: false
    t.decimal "weight", precision: 8, scale: 2, null: false
    t.index ["food_id"], name: "index_meal_template_items_on_food_id"
    t.index ["meal_template_id"], name: "index_meal_template_items_on_meal_template_id"
  end

  create_table "meal_templates", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "name", limit: 255, null: false
    t.datetime "updated_at", null: false
    t.bigint "user_id", null: false
    t.index ["user_id"], name: "index_meal_templates_on_user_id"
  end

  create_table "recipe_ingredients", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.bigint "food_id", null: false
    t.bigint "recipe_id", null: false
    t.datetime "updated_at", null: false
    t.decimal "weight", precision: 8, scale: 2, null: false
    t.index ["food_id"], name: "index_recipe_ingredients_on_food_id"
    t.index ["recipe_id"], name: "index_recipe_ingredients_on_recipe_id"
  end

  create_table "recipes", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.bigint "food_id", null: false
    t.string "name", limit: 255, null: false
    t.decimal "servings_in_recipe", precision: 8, scale: 2, null: false
    t.datetime "updated_at", null: false
    t.bigint "user_id", null: false
    t.index ["food_id"], name: "index_recipes_on_food_id"
    t.index ["user_id"], name: "index_recipes_on_user_id"
  end

  create_table "users", force: :cascade do |t|
    t.bigint "account_id", null: false
    t.integer "carbs_target", default: 250, null: false
    t.string "country"
    t.datetime "created_at", null: false
    t.integer "daily_calorie_target", default: 2000, null: false
    t.string "display_name", default: "", null: false
    t.integer "fat_target", default: 65, null: false
    t.integer "fiber_target", default: 30, null: false
    t.string "language", default: "en", null: false
    t.datetime "onboarded_at"
    t.integer "protein_target", default: 50, null: false
    t.string "timezone", default: "UTC", null: false
    t.integer "unit_preference", default: 0, null: false
    t.datetime "updated_at", null: false
    t.index ["account_id"], name: "index_users_on_account_id", unique: true
  end

  add_foreign_key "account_login_change_keys", "accounts", column: "id"
  add_foreign_key "account_password_reset_keys", "accounts", column: "id"
  add_foreign_key "account_remember_keys", "accounts", column: "id"
  add_foreign_key "account_verification_keys", "accounts", column: "id"
  add_foreign_key "food_log_entries", "foods"
  add_foreign_key "food_log_entries", "users", on_delete: :cascade
  add_foreign_key "foods", "users", column: "creator_id", on_delete: :cascade
  add_foreign_key "meal_template_items", "foods"
  add_foreign_key "meal_template_items", "meal_templates", on_delete: :cascade
  add_foreign_key "meal_templates", "users", on_delete: :cascade
  add_foreign_key "recipe_ingredients", "foods"
  add_foreign_key "recipe_ingredients", "recipes", on_delete: :cascade
  add_foreign_key "recipes", "foods"
  add_foreign_key "recipes", "users", on_delete: :cascade
  add_foreign_key "users", "accounts", on_delete: :cascade
end
