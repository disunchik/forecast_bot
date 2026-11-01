class StandingsController < ApplicationController
  before_action :require_html_response

  def show
    @snapshot = active_season&.standing_snapshots&.joins(:match)&.order("matches.forecast_number DESC")&.first
  end
end
