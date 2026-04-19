class Food < ApplicationRecord
  # All nutritional values are stored per 100 grams.

  belongs_to :creator, class_name: "User", optional: true

  enum :source, { off: 0, usda: 1, user: 2 }

  validates :name, presence: true, length: { maximum: 255 }
  validates :calories, :protein, :carbs, :fat,
    presence: true, numericality: { greater_than_or_equal_to: 0 }
  validates :fiber, numericality: { greater_than_or_equal_to: 0 }
  validates :source, presence: true
  validates :external_id, uniqueness: { scope: :source }, allow_nil: true
  validate :creator_required_for_user_source

  private

  def creator_required_for_user_source
    if user? && creator_id.nil?
      errors.add(:creator_id, "is required for user-created foods")
    end
  end
end
