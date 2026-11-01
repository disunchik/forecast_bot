class MatchRollbackService
  class Error < StandardError; end

  def initialize(season:, keep_through_number:, admin:)
    @season = season
    @keep_through_number = keep_through_number.to_i
    @admin = admin
  end

  def call!
    matches = @season.matches.where("forecast_number > ?", @keep_through_number).order(forecast_number: :desc)

    ActiveRecord::Base.transaction do
      matches.each do |match|
        result = match.match_result
        next unless result&.confirmed?

        GoldPointTransaction.where(match: match, kind: [:stake, :placement]).destroy_all
        result.forecast_scores.destroy_all
        result.update!(state: :draft, confirmed_by: nil, confirmed_at: nil)
        match.update!(status: :scheduled) if match.finished?
      end

      StandingSnapshot.joins(:match)
                      .where(season: @season)
                      .where("matches.forecast_number > ?", @keep_through_number)
                      .destroy_all

      AuditLogger.record!(admin: @admin, action: "season.rollback", auditable: @season, details: { keep_through_number: @keep_through_number })
    end
  end
end
