class Achievement < ApplicationRecord
  has_many :user_achievements, dependent: :destroy
  has_many :users, through: :user_achievements
  belongs_to :first_award_season, class_name: "Season", optional: true

  serialize :competition_ids, coder: JSON
  scope :active, -> { where(active: true) }

  before_validation do
    self.rule_key = rule_key.presence
    self.competition_ids = Array(competition_ids).reject(&:blank?).map(&:to_i).uniq
  end
  validates :name, presence: true, uniqueness: true
  validates :rule_key, inclusion: { in: ->(_) { AchievementRules.keys } }, allow_nil: true
  validate :automatic_competitions_exist

  def rule_label
    AchievementRules.label(rule_key) || "Вручную"
  end

  private
    def automatic_competitions_exist
      return unless rule_key == "europe_exact"

      if competition_ids.empty? || Competition.where(id: competition_ids).count != competition_ids.size
        errors.add(:competition_ids, "выберите турниры для проверки точного счёта")
      end
    end
end
