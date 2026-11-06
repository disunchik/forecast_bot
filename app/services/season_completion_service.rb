class SeasonCompletionService
  class Error < StandardError; end

  def initialize(season:, admin:)
    @season = season
    @admin = admin
  end

  def pending_matches
    @season.matches.left_joins(:match_result).where.not(status: :cancelled)
           .where("match_results.id IS NULL OR match_results.state != ?", MatchResult.states[:confirmed])
           .order(:forecast_number)
  end

  def token
    AdminStateToken.issue(scope: "season_complete", id: @season.id, state: state)
  end

  def complete!(token:, confirmation:)
    raise Error, "Подтвердите завершение сезона" unless confirmation == "1"

    SeasonTransaction.call(@season) do
      @season.reload
      raise Error, "Сезон уже завершён" if @season.completed?
      AdminStateToken.verify!(token, scope: "season_complete", id: @season.id, state: state)
      raise Error, "Сначала подтвердите или отмените все матчи сезона" if pending_matches.exists?
      unless @season.matches.joins(:match_result).where(match_results: { state: :confirmed }).exists?
        raise Error, "Нельзя завершить сезон без подтверждённых результатов"
      end

      awards = AutomaticAchievementsService.new(season: @season, admin: @admin).award!(event: :season)
      @season.update!(completed_at: Time.current, completed_by: @admin)
      AuditLogger.record!(admin: @admin, action: "season.complete", auditable: @season,
                          details: { award_ids: awards.map(&:id), confirmed_matches: @season.matches.finished.count })
      awards
    end
  end

  private
    def state
      { season: @season.reload.attributes, history: MatchAuditSnapshot.season_state(@season),
        achievements: Achievement.order(:id).map(&:attributes), awards: UserAchievement.order(:id).pluck(:id), rules: ScoringRule.snapshot }
    end
end
