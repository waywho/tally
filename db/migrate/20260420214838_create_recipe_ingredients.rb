class CreateRecipeIngredients < ActiveRecord::Migration[8.1]
  def change
    create_table :recipe_ingredients do |t|
      t.references :recipe, null: false, foreign_key: { on_delete: :cascade }
      t.references :food, null: false, foreign_key: true
      t.decimal :weight, precision: 8, scale: 2, null: false

      t.timestamps
    end
  end
end
