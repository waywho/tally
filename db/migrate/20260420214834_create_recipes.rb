class CreateRecipes < ActiveRecord::Migration[8.1]
  def change
    create_table :recipes do |t|
      t.references :user, null: false, foreign_key: { on_delete: :cascade }
      t.string :name, null: false, limit: 255
      t.decimal :servings_in_recipe, precision: 8, scale: 2, null: false
      t.references :food, null: false, foreign_key: true

      t.timestamps
    end
  end
end
