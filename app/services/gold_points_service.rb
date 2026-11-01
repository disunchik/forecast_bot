class GoldPointsService
  class Error < StandardError; end

  def self.manual!(user:, season:, amount:, note:, admin:)
    raise Error, "Нет активного сезона" unless season
    raise Error, "Укажите причину" if note.blank?
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

  def self.award_achievement!(user:, achievement:, admin:, season: Season.active.first)
    raise Error, "Нет активного сезона" unless season
    raise Error, "Ачивка уже выдана" if user.user_achievements.exists?(achievement: achievement)

    ActiveRecord::Base.transaction do
      first_award = achievement.user_achievements.none?
      amount = if first_award
                 achievement.secret? ? ScoringRule.value_for("achievement_secret_first", 5) : ScoringRule.value_for("achievement_normal_first", 3)
               else
                 ScoringRule.value_for("achievement_subsequent", 1)
               end

      award = UserAchievement.create!(user: user, achievement: achievement, awarded_by: admin, awarded_at: Time.current)
      achievement.update!(revealed: true) if first_award && achievement.secret?
      GoldPointTransaction.create!(
        user: user,
        season: season,
        achievement: achievement,
        created_by: admin,
        kind: :achievement,
        amount: amount,
        note: "Ачивка «#{achievement.name}»"
      )
      AuditLogger.record!(admin: admin, action: "achievement.award", auditable: achievement, details: { user_id: user.id, gold_points: amount })
      award
    end
  end
end
