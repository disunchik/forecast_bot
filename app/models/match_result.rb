class MatchResult < ApplicationRecord
  belongs_to :match
  belongs_to :confirmed_by, class_name: "User", optional: true

  has_many :goals, -> { order(:position) }, class_name: "MatchGoal", dependent: :destroy
  has_many :forecast_scores, dependent: :destroy

  enum :first_score, { roma: 0, opponent: 1, nobody: 2 }, prefix: true
  enum :state, { draft: 0, confirmed: 1 }

  validates :halftime_roma, :halftime_opponent, :fulltime_roma, :fulltime_opponent,
            numericality: { only_integer: true, greater_than_or_equal_to: 0 }
  validates :first_score, presence: true
  validate :halftime_not_greater_than_fulltime
  validate :roma_goals_count_matches_score, if: :confirmed?
  validate :first_score_consistency

  private
    def first_score_consistency
      total_goals = fulltime_roma.to_i + fulltime_opponent.to_i
      if total_goals.zero? && !first_score_nobody?
        errors.add(:first_score, "должен быть «Никто» при счёте 0:0")
      elsif total_goals.positive? && first_score_nobody?
        errors.add(:first_score, "не может быть «Никто», если были голы")
      end
    end

    def halftime_not_greater_than_fulltime
      errors.add(:halftime_roma, "не может быть больше итогового счёта") if halftime_roma.to_i > fulltime_roma.to_i
      errors.add(:halftime_opponent, "не может быть больше итогового счёта") if halftime_opponent.to_i > fulltime_opponent.to_i
    end

    def roma_goals_count_matches_score
      errors.add(:goals, "количество голов Ромы должно совпадать с итоговым счётом") if goals.size != fulltime_roma.to_i
    end
end
