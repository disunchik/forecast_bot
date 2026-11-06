class GoldPointsService
  class Error < StandardError; end

  def self.manual!(user:, season:, amount:, note:, admin:)
    raise Error, "Нет активного сезона" unless season

    SeasonTransaction.call(season) do
      manual_transaction!(user: user, season: season, amount: amount, note: note, admin: admin)
    end
  end

  def self.manual_transaction!(user:, season:, amount:, note:, admin:)
    raise Error, "Нет активного сезона" unless season
    raise Error, "Укажите причину" if note.blank?
    raise Error, "Укажите целое число" unless amount.to_s.match?(/\A-?\d+\z/)
    raise Error, "Сумма не может быть нулевой" if amount.to_i.zero?
    if amount.to_i.negative? && user.gold_points_balance(season) + amount.to_i < user.reserved_gold_points(season)
      raise Error, "Нельзя списать ЗБ, которые уже зарезервированы в открытых прогнозах"
    end

    transaction = GoldPointTransaction.create!(
      user: user,
      season: season,
      kind: :manual,
      amount: amount.to_i,
      note: note,
      created_by: admin
    )
    AuditLogger.record!(admin: admin, action: "gold_points.manual", auditable: user, details: { amount: amount.to_i, note: note, season_id: season.id })
    transaction
  end

  private_class_method :manual_transaction!

  def self.award_achievement!(user:, achievement:, admin:, season: Season.active.first)
    previous_award = user.user_achievements.find_by(achievement: achievement)
    if previous_award
      raise Error, previous_award.revoked? ? "Ачивка отозвана. Восстановите исходную выдачу в истории ачивки." : "Ачивка уже выдана"
    end

    awards = award_achievements!(users: [ user ], achievement: achievement, admin: admin, season: season)
    raise Error, "Ачивка уже выдана" if awards.empty?
    awards.first
  end

  def self.award_achievements!(users:, achievement:, admin:, season:, round: nil, source: "manual")
    raise Error, "Нет активного сезона" unless season

    SeasonTransaction.call(season) do
      achievement.reload
      raise Error, "Ачивка недоступна для выдачи" unless achievement.active?
      # SQLite serializes writers before this read, including across seasons.
      round ||= season.matches.joins(:match_result).where(match_results: { state: :confirmed }).maximum(:forecast_number) || 0
      awarded_ids = achievement.user_achievements.pluck(:user_id)
      recipients = users.uniq(&:id).reject { |user| awarded_ids.include?(user.id) }
      next [] if recipients.empty?

      first_award = awarded_ids.empty?
      first_cohort = first_award || (achievement.first_award_season_id == season.id && achievement.first_award_round == round)
      first_amount = achievement.secret? ? ScoringRule.value_for("achievement_secret_first", 5) : ScoringRule.value_for("achievement_normal_first", 3)
      amount = first_cohort ? (achievement.first_award_points || first_amount) : ScoringRule.value_for("achievement_subsequent", 1)
      if first_award
        achievement.update!(first_award_season: season, first_award_round: round, first_award_points: amount)
      end

      recipients.map do |user|
        award = UserAchievement.create!(user: user, achievement: achievement, awarded_by: admin, awarded_at: Time.current)
        if amount.positive?
          GoldPointTransaction.create!(user: user, season: season, achievement: achievement, created_by: admin,
                                       kind: :achievement, amount: amount, note: "Ачивка «#{achievement.name}»")
        end
        AuditLogger.record!(admin: admin, action: "achievement.award", auditable: achievement,
                            details: { user_id: user.id, gold_points: amount, season_id: season.id, round: round, source: source })
        award
      end
    end
  end
end
