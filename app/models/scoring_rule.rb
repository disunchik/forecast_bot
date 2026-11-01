class ScoringRule < ApplicationRecord
  DEFAULT_VALUES = {
    "halftime_difference" => 2, "halftime_exact" => 2,
    "fulltime_difference" => 4, "fulltime_exact" => 4, "outcome" => 2,
    "roma_no_goal" => 1, "nil_nil" => 2, "first_score" => 1,
    "scorer_1_4" => 3, "scorer_5_6" => 2, "scorer_7_8" => 1,
    "assist_1_4" => 2, "assist_5_plus" => 1, "gold_percentage" => 50,
    "placement_first" => 3, "placement_second" => 2, "placement_third" => 1,
    "achievement_secret_first" => 5, "achievement_normal_first" => 3,
    "achievement_subsequent" => 1, "player_mention_limit" => 13
  }.freeze
  validates :key, presence: true, uniqueness: true
  validates :label, presence: true
  validates :value, numericality: { only_integer: true, greater_than_or_equal_to: 0 }

  def self.value_for(key, fallback = 0)
    find_by(key: key.to_s)&.value || fallback
  end

  def self.snapshot
    DEFAULT_VALUES.merge(pluck(:key, :value).to_h)
  end
end
