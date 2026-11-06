class AchievementRevealService
  def self.call
    Achievement.where(secret: true, revealed: false).where.not(first_award_season_id: nil).find_each do |achievement|
      next unless next_round_opened?(achievement)

      Achievement.transaction do
        # Keep disclosure permanent even if a match is subsequently postponed or rolled back.
        changed = Achievement.where(id: achievement.id, revealed: false).update_all(revealed: true, updated_at: Time.current)
        if changed.positive?
          AuditLogger.record!(admin: nil, action: "achievement.reveal", auditable: achievement,
                              details: { first_award_season_id: achievement.first_award_season_id, first_award_round: achievement.first_award_round })
        end
      end
    end
  end

  def self.next_round_opened?(achievement)
    eligible = Match.where(status: [ :scheduled, :finished ]).where("kickoff_at <= ?", 48.hours.from_now)
    return true if eligible.where(season_id: achievement.first_award_season_id)
                           .where("forecast_number > ?", achievement.first_award_round).exists?

    # The last round's secret is disclosed when forecasts open in the next active season.
    eligible.joins(:season).where(seasons: { active: true })
            .where.not(season_id: achievement.first_award_season_id).exists?
  end
  private_class_method :next_round_opened?
end
