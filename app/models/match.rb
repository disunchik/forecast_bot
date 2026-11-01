class Match < ApplicationRecord
  belongs_to :season
  belongs_to :competition

  has_one :temporary_question, dependent: :destroy
  has_many :forecasts, dependent: :destroy
  has_one :match_result, dependent: :destroy
  has_one :standing_snapshot, dependent: :destroy

  enum :venue, { home: 0, away: 1 }
  enum :status, { scheduled: 0, postponed: 1, cancelled: 2, finished: 3 }

  validates :forecast_number, presence: true, numericality: { only_integer: true, greater_than_or_equal_to: 0 }, uniqueness: { scope: :season_id }
  validates :opponent, presence: true, length: { maximum: 80 }
  validates :kickoff_at, presence: true
  validate :finished_requires_confirmed_result

  scope :chronological, -> { order(:kickoff_at) }

  def forecast_opens_at
    kickoff_at - 48.hours
  end

  def forecast_closes_at
    kickoff_at - 2.hours
  end

  def forecast_open?(at: Time.current)
    scheduled? && at >= forecast_opens_at && at < forecast_closes_at
  end

  def forecast_closed?(at: Time.current)
    at >= forecast_closes_at || cancelled? || finished?
  end

  def predictions_visible_to_all?(at: Time.current)
    at >= forecast_closes_at || cancelled? || finished?
  end

  def roma_name
    "Рома"
  end

  def display_home_team
    home? ? roma_name : opponent
  end

  def display_away_team
    home? ? opponent : roma_name
  end

  private
    def finished_requires_confirmed_result
      if finished? && !match_result&.confirmed?
        errors.add(:status, "«Завершён» устанавливается только после подтверждения результата")
      end
    end
end
