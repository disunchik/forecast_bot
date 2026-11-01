module Admin
  class StandingsController < BaseController
    def show
      @season = params[:season_id].present? ? Season.find(params[:season_id]) : active_season
      @snapshots = @season ? @season.standing_snapshots.joins(:match).order("matches.forecast_number DESC") : StandingSnapshot.none
      @snapshot = params[:snapshot_id].present? ? @snapshots.find(params[:snapshot_id]) : @snapshots.first
    end

    def rebuild
      season = Season.find(params[:season_id])
      if params[:reason].blank?
        redirect_to admin_standings_path(season_id: season.id), alert: "Укажите причину пересборки."
        return
      end
      SeasonTransaction.call(season) do
        season.matches.joins(:match_result).where(match_results: { state: :confirmed }).order(:forecast_number).each do |match|
          StandingsCalculator.new(match: match).rebuild_snapshot!
        end
        AuditLogger.record!(admin: current_user, action: "standings.rebuild", auditable: season, details: { reason: params[:reason] })
      end
      redirect_to admin_standings_path(season_id: season.id), notice: "Таблица пересобрана по сохранённым очкам."
    end
  end
end
