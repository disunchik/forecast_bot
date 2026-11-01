class ScoringRule < ApplicationRecord
  validates :key, presence: true, uniqueness: true
  validates :label, presence: true
  validates :value, numericality: { only_integer: true, greater_than_or_equal_to: 0 }

  def self.value_for(key, fallback = 0)
    find_by(key: key.to_s)&.value || fallback
  end
end
