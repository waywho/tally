class FoodLogEntry < ApplicationRecord
  belongs_to :user
  belongs_to :food

  enum :meal, { breakfast: 0, lunch: 1, dinner: 2, snacks: 3 }

  validates :logged_on, presence: true
  validates :meal, presence: true
  validates :quantity_g, presence: true, numericality: { greater_than: 0 }

  def calories
    food.calories * quantity_g / 100
  end

  def protein
    food.protein * quantity_g / 100
  end

  def carbs
    food.carbs * quantity_g / 100
  end

  def fat
    food.fat * quantity_g / 100
  end

  def fiber
    food.fiber * quantity_g / 100
  end
end
