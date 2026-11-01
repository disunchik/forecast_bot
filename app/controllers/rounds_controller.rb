class RoundsController < ApplicationController
  before_action :require_html_response

  def index
    @matches = active_season ? active_season.matches.includes(:competition, :match_result).order(forecast_number: :desc) : Match.none
  end

  def show
    @match = Match.where(season: active_season).find(params[:id])
    unless @match.predictions_visible_to_all?
      redirect_to rounds_path, alert: "Прогнозы участников пока скрыты."
      return
    end

    @forecasts = @match.forecasts.includes(:user, :scorers, :forecast_assists, :forecast_score).sort_by do |forecast|
      forecast.forecast_score&.placement || 1_000_000
    end
  end
end
