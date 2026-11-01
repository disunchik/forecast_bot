class HomeController < ApplicationController
  def index
    return unless active_season

    @open_matches = active_season.matches.chronological.select(&:forecast_open?)
    @upcoming_match = active_season.matches.scheduled.where("kickoff_at > ?", Time.current).order(:kickoff_at).first
    @forecasts = current_user.forecasts.where(match: @open_matches).index_by(&:match_id)
  end
end
