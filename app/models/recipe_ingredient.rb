class RecipeIngredient < ApplicationRecord
  belongs_to :recipe
  belongs_to :food

  validates :weight, presence: true, numericality: { greater_than: 0 }
end
