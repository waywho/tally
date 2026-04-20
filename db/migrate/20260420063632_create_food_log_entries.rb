class CreateFoodLogEntries < ActiveRecord::Migration[8.1]
  def change
    create_table :food_log_entries do |t|
      t.references :user, null: false, foreign_key: { on_delete: :cascade }
      t.references :food, null: false, foreign_key: true
      t.date :logged_on, null: false
      t.integer :meal, null: false
      t.decimal :quantity_g, precision: 8, scale: 2, null: false

      t.timestamps
    end

    add_index :food_log_entries, [:user_id, :logged_on]
    add_index :food_log_entries, [:user_id, :food_id]
  end
end
