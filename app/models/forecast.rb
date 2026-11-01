class Forecast < ApplicationRecord
  belongs_to :user
  belongs_to :match
  belongs_to :temporary_question_option, optional: true

  has_many :forecast_scorers, dependent: :destroy
  has_many :scorers, through: :forecast_scorers, source: :player
  has_many :forecast_assists, dependent: :destroy
  has_one :forecast_score, dependent: :destroy

  enum :first_score, { roma: 0, opponent: 1, nobody: 2 }, prefix: true

  validates :halftime_roma, :halftime_opponent, :fulltime_roma, :fulltime_opponent,
            numericality: { only_integer: true, greater_than_or_equal_to: 0 }
  validates :gold_points_stake, numericality: { only_integer: true, greater_than_or_equal_to: 0 }
  validates :submitted_at, presence: true
  validates :first_score, presence: true
  validates :match_id, uniqueness: { scope: :user_id }
  validate :halftime_not_greater_than_fulltime
  validate :temporary_question_answer_present
  validate :temporary_option_belongs_to_match
  validate :first_score_consistency

  def assist_player_ids
    forecast_assists.reject(&:no_assist?).map(&:player_id).compact
  end

  def predicts_no_assist?
    forecast_assists.any?(&:no_assist?)
  end

  private
    def halftime_not_greater_than_fulltime
      errors.add(:halftime_roma, "не может быть больше итогового счёта") if halftime_roma.to_i > fulltime_roma.to_i
      errors.add(:halftime_opponent, "не может быть больше итогового счёта") if halftime_opponent.to_i > fulltime_opponent.to_i
    end

    def temporary_option_belongs_to_match
      return if temporary_question_option_id.blank?
      question = match&.temporary_question
      return if question&.options&.where(id: temporary_question_option_id)&.exists?

      errors.add(:base, "Некорректный вариант временного вопроса")
    end

    def first_score_consistency
      total_goals = fulltime_roma.to_i + fulltime_opponent.to_i
      if total_goals.zero? && !first_score_nobody?
        errors.add(:first_score, "должен быть «Голов не будет» при прогнозе 0:0")
      elsif total_goals.positive? && first_score_nobody?
        errors.add(:first_score, "не может быть «Голов не будет», если в прогнозе есть голы")
      end
    end

    def temporary_question_answer_present
      question = match&.temporary_question
      return unless question

      if question.choice? && temporary_question_option_id.blank?
        errors.add(:base, "Ответьте на временный вопрос")
      elsif question.text? && temporary_answer_text.blank?
        errors.add(:base, "Ответьте на временный вопрос")
      end
    end
end
