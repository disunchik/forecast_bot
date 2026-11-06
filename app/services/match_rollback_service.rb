class MatchRollbackService
  class Error < StandardError; end

  def initialize(season:, keep_through_number:, admin:)
    @season = season
    @keep_through_number = Integer(keep_through_number.to_s, 10)
    @admin = admin
  end

  def call!(reason: nil)
    perform!(reason: reason)
  end

  def affected_matches
    @season.matches.joins(:match_result)
           .where(match_results: { state: :confirmed })
           .where("forecast_number > ?", @keep_through_number).order(:forecast_number)
  end

  def token
    AdminStateToken.issue(scope: "rollback:#{@keep_through_number}", id: @season.id, state: MatchAuditSnapshot.season_state(@season))
  end

  def confirm!(token:, reason:, confirmation:)
    raise Error, "Укажите причину отката и подтвердите последствия" if reason.blank? || confirmation != "1"

    SeasonTransaction.call(@season) do
      AdminStateToken.verify!(token, scope: "rollback:#{@keep_through_number}", id: @season.id, state: MatchAuditSnapshot.season_state(@season))
      perform!(reason: reason)
    end
  end

  private

  def perform!(reason: nil)
    matches = @season.matches.where("forecast_number > ?", @keep_through_number).order(forecast_number: :desc)

    SeasonTransaction.call(@season) do
      @season.reload
      if @season.completed? && affected_matches.exists?
        @season.update!(completed_at: nil, completed_by: nil)
        AuditLogger.record!(admin: @admin, action: "season.reopen", auditable: @season,
                            details: { reason: reason, achievements_preserved: true })
      end
      matches.each do |match|
        result = match.match_result
        next unless result&.confirmed?

        # Reverse spending with a new ledger entry. Original transactions remain.
        spent = GoldPointTransaction.where(match: match, kind: [ :stake, :stake_refund ]).group(:user_id).sum(:amount)
        spent.each do |user_id, net_amount|
          next unless net_amount.negative?

          GoldPointTransaction.create!(user_id: user_id, season: @season, match: match, kind: :stake_refund,
                                       amount: -net_amount, created_by: @admin, note: "Возврат ставки при откате матча №#{match.forecast_number}")
        end
        result.forecast_scores.destroy_all
        result.update!(state: :draft, confirmed_by: nil, confirmed_at: nil)
        match.update!(status: :scheduled) if match.finished?
      end

      StandingSnapshot.joins(:match)
                      .where(season: @season)
                      .where("matches.forecast_number > ?", @keep_through_number)
                      .destroy_all

      AuditLogger.record!(admin: @admin, action: "season.rollback", auditable: @season,
                          details: { keep_through_number: @keep_through_number, placement_gold_preserved: true, reason: reason })
    end
  end
end
