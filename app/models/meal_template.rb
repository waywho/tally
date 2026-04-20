class MealTemplate < ApplicationRecord
  belongs_to :user
  has_many :meal_template_items, dependent: :destroy

  validates :name, presence: true, length: { maximum: 255 }
end
