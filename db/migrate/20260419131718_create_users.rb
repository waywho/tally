class CreateUsers < ActiveRecord::Migration[8.1]
  def change
    create_table :users do |t|
      t.references :account, null: false, foreign_key: { on_delete: :cascade }, index: { unique: true }
      t.string :display_name, default: "", null: false
      t.integer :daily_calorie_target, default: 2000, null: false
      t.integer :protein_target, default: 50, null: false
      t.integer :carbs_target, default: 250, null: false
      t.integer :fat_target, default: 65, null: false
      t.integer :fiber_target, default: 30, null: false
      t.string :timezone, default: "UTC", null: false
      t.integer :unit_preference, default: 0, null: false
      t.string :country
      t.string :language, default: "en", null: false

      t.timestamps
    end
  end
end
