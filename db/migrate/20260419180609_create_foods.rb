class CreateFoods < ActiveRecord::Migration[8.1]
  def change
    enable_extension "pg_trgm"

    create_table :foods do |t|
      t.string :name, null: false, limit: 255
      t.string :brand
      t.string :barcode
      t.decimal :serving_size, precision: 8, scale: 2
      t.string :serving_label
      t.decimal :calories, precision: 8, scale: 2, null: false
      t.decimal :protein, precision: 8, scale: 2, null: false
      t.decimal :carbs, precision: 8, scale: 2, null: false
      t.decimal :fat, precision: 8, scale: 2, null: false
      t.decimal :fiber, precision: 8, scale: 2, null: false, default: 0
      t.integer :source, null: false
      t.string :external_id
      t.references :creator, null: true, foreign_key: { to_table: :users, on_delete: :cascade }
      t.datetime :verified_at

      t.timestamps
    end

    add_index :foods, :barcode
    add_index :foods, [:source, :external_id], unique: true, where: "external_id IS NOT NULL"
    add_index :foods, :name, using: :gin, opclass: :gin_trgm_ops, name: "index_foods_on_name_trigram"

    reversible do |dir|
      dir.up do
        execute <<~SQL
          ALTER TABLE foods ADD COLUMN searchable tsvector
            GENERATED ALWAYS AS (
              to_tsvector('english', coalesce(name, '') || ' ' || coalesce(brand, ''))
            ) STORED;
        SQL
        execute <<~SQL
          CREATE INDEX index_foods_on_searchable ON foods USING gin(searchable);
        SQL
      end
    end
  end
end
