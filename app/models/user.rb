class User < ApplicationRecord
  has_secure_password

  has_many :sessions, dependent: :destroy
  has_many :forecasts, dependent: :destroy
  has_many :forecast_scores, through: :forecasts
  has_many :gold_point_transactions, dependent: :destroy
  has_many :user_achievements, dependent: :destroy
  has_many :achievements, through: :user_achievements

  enum :role, { user: 0, admin: 1 }

  normalizes :email_address, with: ->(value) { value&.strip&.downcase }
  normalizes :nickname, with: ->(value) { value&.strip }
  before_validation :set_nickname_key

  validates :nickname,
            presence: true,
            length: { in: 2..20 },
            format: { with: /\A[\p{L}\p{N}_\- ]+\z/u },
            uniqueness: { case_sensitive: false }
  validates :email_address,
            presence: true,
            format: { with: /\A[^@\s]+@[^@\s]+\z/ },
            uniqueness: { case_sensitive: false },
            unless: :legacy_account?
  validates :nickname_key, presence: true, uniqueness: true
  validates :password, length: { minimum: 8 }, if: -> { password.present? && !legacy_account? }
  validates :password_confirmation, presence: true, if: -> { password.present? }

  def needs_legacy_setup?
    legacy_account? || must_change_password? || email_address.blank?
  end

  def gold_points_balance(season = Season.active.first)
    return 0 unless season

    gold_point_transactions.where(season: season).sum(:amount)
  end

  def reserved_gold_points(season = Season.active.first)
    return 0 unless season

    forecasts.joins(:match)
             .where(matches: { season_id: season.id })
             .where.not(matches: { status: Match.statuses[:cancelled] })
             .left_joins(:forecast_score)
             .where(forecast_scores: { id: nil })
             .sum(:gold_points_stake)
  end

  def available_gold_points(season = Season.active.first)
    [ gold_points_balance(season) - reserved_gold_points(season), 0 ].max
  end

  def self.nickname_key_for(value)
    value.to_s.strip.downcase
  end

  private
    def set_nickname_key
      self.nickname_key = self.class.nickname_key_for(nickname)
    end
end
