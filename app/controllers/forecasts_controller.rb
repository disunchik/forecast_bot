class ForecastsController < ApplicationController
  before_action :set_match
  before_action :set_forecast, only: %i[show edit update]
  before_action :ensure_forecast_open, only: %i[new create edit update]

  def show
    unless @forecast.user == current_user || @match.predictions_visible_to_all?
      redirect_to root_path, alert: "Чужие прогнозы откроются после дедлайна."
    end
  end

  def new
    if (existing = current_user.forecasts.find_by(match: @match))
      redirect_to edit_match_forecast_path(@match, existing)
      return
    end

    @forecast = current_user.forecasts.new(match: @match, submitted_at: Time.current)
    prepare_form
  end

  def create
    @forecast = current_user.forecasts.new(match: @match, submitted_at: Time.current)
    assign_forecast

    if valid_for_submission? && persist_forecast!
      redirect_to root_path, notice: "Прогноз сохранён."
    else
      prepare_form
      render :new, status: :unprocessable_entity
    end
  end

  def edit
    raise ActiveRecord::RecordNotFound unless @forecast.user == current_user
    prepare_form
  end

  def update
    raise ActiveRecord::RecordNotFound unless @forecast.user == current_user
    assign_forecast

    if valid_for_submission? && persist_forecast!
      redirect_to root_path, notice: "Прогноз обновлён."
    else
      prepare_form
      render :edit, status: :unprocessable_entity
    end
  end

  private
    def set_match
      @match = Match.find(params[:match_id])
    end

    def set_forecast
      @forecast = @match.forecasts.find(params[:id])
    end

    def ensure_forecast_open
      return if @match.forecast_open?

      redirect_to root_path, alert: "Приём прогнозов на этот матч закрыт."
    end

    def prepare_form
      @players = Player.active
      @limits = PlayerLimitsService.new(user: current_user, match: @match, forecast: @forecast)
      @available_gold = current_user.available_gold_points(@match.season) + (@forecast.persisted? ? @forecast.gold_points_stake : 0)
      @selected_scorer_ids ||= @forecast.scorer_ids
      @selected_assist_ids ||= @forecast.assist_player_ids
      @selected_no_assist = @forecast.predicts_no_assist? if @selected_no_assist.nil?
    end

    def assign_forecast
      attrs = forecast_params.except(:scorer_ids, :assist_player_ids, :no_assist)
      @forecast.assign_attributes(attrs)
      @forecast.submitted_at = Time.current
      @selected_scorer_ids = Array(forecast_params[:scorer_ids]).reject(&:blank?).map(&:to_i).uniq
      @selected_assist_ids = Array(forecast_params[:assist_player_ids]).reject(&:blank?).map(&:to_i).uniq
      @selected_no_assist = ActiveModel::Type::Boolean.new.cast(forecast_params[:no_assist])
    end

    def valid_for_submission?
      @forecast.valid?
      validate_selections
      validate_gold_points
      validate_player_limits
      @forecast.errors.empty?
    end

    def validate_selections
      active_ids = Player.active.where(id: @selected_scorer_ids + @selected_assist_ids).pluck(:id)
      missing_ids = (@selected_scorer_ids + @selected_assist_ids).uniq - active_ids
      @forecast.errors.add(:base, "Выбран неактивный или неизвестный игрок") if missing_ids.any?

      if @selected_scorer_ids.size > @forecast.fulltime_roma.to_i
        @forecast.errors.add(:base, "Авторов голов не может быть больше, чем голов Ромы в прогнозе")
      end
      if @selected_scorer_ids.size > 8
        @forecast.errors.add(:base, "Можно выбрать не более 8 авторов голов")
      end

      assist_selections = @selected_assist_ids.size + (@selected_no_assist ? 1 : 0)
      if assist_selections > @forecast.fulltime_roma.to_i
        @forecast.errors.add(:base, "Вариантов ассистов не может быть больше, чем голов Ромы в прогнозе")
      end
    end

    def validate_gold_points
      available = current_user.available_gold_points(@match.season) + (@forecast.persisted? ? @forecast.gold_points_stake_was.to_i : 0)
      if @forecast.gold_points_stake.to_i > available
        @forecast.errors.add(:gold_points_stake, "недостаточно доступных ЗБ")
      end
    end

    def validate_player_limits
      limits = PlayerLimitsService.new(user: current_user, match: @match, forecast: @forecast)
      Player.where(id: @selected_scorer_ids).each do |player|
        @forecast.errors.add(:base, "Лимит на голы для #{player.name} исчерпан") unless limits.scorer_available?(player)
      end
      Player.where(id: @selected_assist_ids).each do |player|
        @forecast.errors.add(:base, "Лимит на ассисты для #{player.name} исчерпан") unless limits.assist_available?(player)
      end
    end

    def persist_forecast!
      success = true
      ActiveRecord::Base.transaction do
        current_user.with_lock do
          available = current_user.available_gold_points(@match.season) + (@forecast.persisted? ? @forecast.gold_points_stake_was.to_i : 0)
          if @forecast.gold_points_stake.to_i > available
            @forecast.errors.add(:gold_points_stake, "недостаточно доступных ЗБ")
            success = false
            raise ActiveRecord::Rollback
          end

          @forecast.save!
          @forecast.forecast_scorers.delete_all
          @selected_scorer_ids.each { |id| @forecast.forecast_scorers.create!(player_id: id) }

          @forecast.forecast_assists.delete_all
          @selected_assist_ids.each { |id| @forecast.forecast_assists.create!(player_id: id) }
          @forecast.forecast_assists.create!(no_assist: true) if @selected_no_assist
        end
      end
      success
    rescue ActiveRecord::RecordInvalid => e
      @forecast.errors.merge!(e.record.errors) if e.record != @forecast
      false
    end

    def forecast_params
      params.require(:forecast).permit(
        :temporary_question_option_id,
        :temporary_answer_text,
        :halftime_roma,
        :halftime_opponent,
        :fulltime_roma,
        :fulltime_opponent,
        :first_score,
        :gold_points_stake,
        :no_assist,
        scorer_ids: [],
        assist_player_ids: []
      )
    end
end
