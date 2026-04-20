class FoodLogEntry < ApplicationRecord
  belongs_to :user
  belongs_to :food

  enum :meal, { breakfast: 0, lunch: 1, dinner: 2, snacks: 3 }

  validates :logged_on, presence: true
  validates :meal, presence: true
  validates :weight, presence: true, numericality: { greater_than: 0 }

  def calories
    food.calories * weight / 100
  end

  def protein
    food.protein * weight / 100
  end

  def carbs
    food.carbs * weight / 100
  end

  def fat
    food.fat * weight / 100
  end

  def fiber
    food.fiber * weight / 100
  end
end
