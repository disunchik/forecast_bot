module Admin
  class ResultsController < BaseController
    def index
      @season = params[:season_id].present? ? Season.find(params[:season_id]) : active_season
      @matches = @season ? @season.matches.includes(:competition, :match_result).order(:forecast_number) : Match.none
    end
  end
end
