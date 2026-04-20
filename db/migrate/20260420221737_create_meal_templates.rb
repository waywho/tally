class CreateMealTemplates < ActiveRecord::Migration[8.1]
  def change
    create_table :meal_templates do |t|
      t.references :user, null: false, foreign_key: { on_delete: :cascade }
      t.string :name, null: false, limit: 255

      t.timestamps
    end
  end
end
