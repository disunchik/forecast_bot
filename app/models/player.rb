class Player < ApplicationRecord
  has_many :forecast_scorers, dependent: :restrict_with_error
  has_many :forecast_assists, dependent: :restrict_with_error
  has_many :scored_match_goals, class_name: "MatchGoal", foreign_key: :scorer_id, dependent: :restrict_with_error
  has_many :assisted_match_goals, class_name: "MatchGoal", foreign_key: :assist_id, dependent: :restrict_with_error

  scope :active, -> { where(active: true).order(:name) }
  scope :inactive, -> { where(active: false).order(:name) }

  validates :name, presence: true, uniqueness: { case_sensitive: false }
end
