class ForecastSubmissionService
  def initialize(forecast:, scorer_ids: [], assist_player_ids: [], no_assist: false)
    @forecast = forecast
    @user = forecast.user
    @match = forecast.match
    @scorer_ids = scorer_ids.map(&:to_i).uniq
    @assist_ids = assist_player_ids.map(&:to_i).uniq
    @no_assist = no_assist
  end

  def call
    saved = false
    SeasonTransaction.call(@match.season) do
      @match.reload
      @forecast.match = @match
      @forecast.submitted_at = Time.current
      @forecast.valid?
      if !@match.season.active? || !@match.forecast_open?
        @forecast.errors.add(:base, "Приём прогнозов на этот матч закрыт")
      end
      previous_stake = @forecast.persisted? ? @user.forecasts.find(@forecast.id).gold_points_stake : 0
      available = @user.available_gold_points(@match.season) + previous_stake
      @forecast.errors.add(:gold_points_stake, "недостаточно доступных ЗБ") if @forecast.gold_points_stake.to_i > available
      validate_players
      raise ActiveRecord::Rollback if @forecast.errors.any?

      @forecast.save!
      @forecast.forecast_scorers.delete_all
      @scorer_ids.each { |id| @forecast.forecast_scorers.create!(player_id: id) }
      @forecast.forecast_assists.delete_all
      @assist_ids.each { |id| @forecast.forecast_assists.create!(player_id: id) }
      @forecast.forecast_assists.create!(no_assist: true) if @no_assist
      saved = true
    end
    saved
  rescue ActiveRecord::RecordInvalid => e
    @forecast.errors.merge!(e.record.errors) unless e.record == @forecast
    false
  rescue ActiveRecord::RecordNotFound, ActiveRecord::RecordNotUnique
    @forecast.errors.add(:base, "Прогноз или матч изменился. Обновите страницу и повторите сохранение.")
    false
  end

  private
    def validate_players
      ids = @scorer_ids | @assist_ids
      if (ids - Player.active.where(id: ids).pluck(:id)).any?
        @forecast.errors.add(:base, "Выбран неактивный или неизвестный игрок")
      end
      if @scorer_ids.size > @forecast.fulltime_roma.to_i || @scorer_ids.size > 8
        @forecast.errors.add(:base, "Авторов голов не может быть больше голов Ромы или больше восьми")
      end
      if @assist_ids.size + (@no_assist ? 1 : 0) > @forecast.fulltime_roma.to_i
        @forecast.errors.add(:base, "Вариантов ассистов не может быть больше голов Ромы")
      end
      limits = PlayerLimitsService.new(user: @user, match: @match, forecast: @forecast)
      Player.where(id: @scorer_ids).each do |player|
        @forecast.errors.add(:base, "Лимит на голы для #{player.name} исчерпан") unless limits.scorer_available?(player)
      end
      Player.where(id: @assist_ids).each do |player|
        @forecast.errors.add(:base, "Лимит на ассисты для #{player.name} исчерпан") unless limits.assist_available?(player)
      end
    end
end
