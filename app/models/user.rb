class User < ApplicationRecord
  belongs_to :account
  has_many :created_foods, class_name: "Food", foreign_key: :creator_id, dependent: :destroy
  has_many :food_log_entries, dependent: :destroy
  has_many :recipes, dependent: :destroy
  has_many :meal_templates, dependent: :destroy

  enum :unit_preference, { metric: 0, imperial: 1 }, default: :metric

  FUN_NAME_ADJECTIVES = %w[
    Happy Brave Sunny Cheerful Mighty Radiant Gentle Bold Bright Lively
    Jolly Swift Calm Kind Merry Keen Wise Noble Spirited Zesty
  ].freeze

  FUN_NAME_ANIMALS = %w[
    Otter Fox Panda Owl Dolphin Rabbit Koala Penguin Falcon Hedgehog
    Deer Squirrel Robin Butterfly Hummingbird Lynx Seal Crane Gecko Sparrow
  ].freeze

  def self.generate_fun_name
    "#{FUN_NAME_ADJECTIVES.sample} #{FUN_NAME_ANIMALS.sample}"
  end

  validates :daily_calorie_target, presence: true,
    numericality: { only_integer: true, in: 1..10_000 }
  validates :protein_target, :carbs_target, :fat_target, :fiber_target,
    presence: true,
    numericality: { only_integer: true, in: 0..1_000 }
  validates :timezone, presence: true,
    inclusion: { in: ActiveSupport::TimeZone::MAPPING.keys }
  validates :language, presence: true,
    inclusion: { in: ->(_) { I18n.available_locales.map(&:to_s) } }
  validates :country, allow_blank: true,
    format: { with: /\A[A-Z]{2}\z/, message: "must be a valid ISO 3166-1 alpha-2 code" }
  validate :country_must_be_valid_iso3166, if: -> { country.present? }
  validates :display_name, length: { maximum: 100 }

  private

  def country_must_be_valid_iso3166
    unless ISO3166::Country.new(country)
      errors.add(:country, "is not a valid country code")
    end
  end
end
