class CreateMealTemplateItems < ActiveRecord::Migration[8.1]
  def change
    create_table :meal_template_items do |t|
      t.references :meal_template, null: false, foreign_key: { on_delete: :cascade }
      t.references :food, null: false, foreign_key: true
      t.decimal :weight, precision: 8, scale: 2, null: false

      t.timestamps
    end
  end
end
