class MatchDestructionService
  class Error < StandardError; end

  def initialize(match:, admin:)
    @match = match
    @admin = admin
    @season = match.season
  end

  def affected_matches
    return Match.none unless @match.match_result&.confirmed?

    rollback.affected_matches
  end

  def token
    AdminStateToken.issue(scope: "match_delete", id: @match.id, state: MatchAuditSnapshot.season_state(@season))
  end

  def call!(token:, reason:, confirmation:)
    if reason.blank? || confirmation.to_s != @match.forecast_number.to_s
      raise Error, "Укажите причину и введите номер удаляемого матча для подтверждения"
    end

    SeasonTransaction.call(@season) do
      AdminStateToken.verify!(token, scope: "match_delete", id: @match.id, state: MatchAuditSnapshot.season_state(@season))
      @match.reload
      snapshot = MatchAuditSnapshot.match_state(@match).merge("forecasts" => MatchAuditSnapshot.forecasts(@match))
      affected = affected_matches.pluck(:forecast_number)
      rollback.call!(reason: reason) if @match.match_result&.confirmed?
      transactions = @match.gold_point_transactions.order(:id).map(&:attributes)
      # Keep the complete ledger and user balances after deleting the match.
      @match.gold_point_transactions.update_all(match_id: nil)
      AuditLogger.record!(admin: @admin, action: "match.destroy", auditable: @match,
                          details: { reason: reason, match: snapshot, gold_transactions: transactions, rolled_back_numbers: affected })
      @match.reload.destroy!
    end
  end

  private
    def rollback
      MatchRollbackService.new(season: @season, keep_through_number: @match.forecast_number - 1, admin: @admin)
    end
end
