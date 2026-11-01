class PlayerLimitsService
  LIMIT = 13

  def initialize(user:, match:, forecast: nil)
    @user = user
    @match = match
    @forecast = forecast
  end

  def scorer_usage(player)
    base_scorer_scope.where(player: player).distinct.count(:forecast_id)
  end

  def assist_usage(player)
    base_assist_scope.where(player: player).distinct.count(:forecast_id)
  end

  def scorer_available?(player)
    scorer_usage(player) < limit
  end

  def assist_available?(player)
    assist_usage(player) < limit
  end

  def limit
    ScoringRule.value_for("player_mention_limit", LIMIT)
  end

  private
    def period_range
      @match.forecast_number <= 19 ? (0..19) : (20..)
    end

    def forecast_scope
      scope = Forecast.joins(:match)
                      .where(user: @user, matches: { season_id: @match.season_id, forecast_number: period_range })
                      .where.not(matches: { status: Match.statuses[:cancelled] })
      scope = scope.where.not(id: @forecast.id) if @forecast&.persisted?
      scope
    end

    def base_scorer_scope
      ForecastScorer.joins(:forecast).where(forecast_id: forecast_scope.select(:id))
    end

    def base_assist_scope
      ForecastAssist.joins(:forecast)
                    .where(no_assist: false)
                    .where(forecast_id: forecast_scope.select(:id))
    end
end
