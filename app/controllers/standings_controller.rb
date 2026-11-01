class StandingsController < ApplicationController
  def show
    @snapshot = active_season&.standing_snapshots&.joins(:match)&.order("matches.forecast_number DESC")&.first
  end
end
