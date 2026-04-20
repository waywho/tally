class MealTemplateItem < ApplicationRecord
  belongs_to :meal_template
  belongs_to :food

  validates :weight, presence: true, numericality: { greater_than: 0 }
end
