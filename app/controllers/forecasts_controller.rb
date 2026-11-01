class ForecastsController < ApplicationController
  before_action :require_html_response, only: :show
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

    if persist_forecast!
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

    if persist_forecast!
      redirect_to root_path, notice: "Прогноз обновлён."
    else
      prepare_form
      render :edit, status: :unprocessable_entity
    end
  end

  private
    def set_match
      scope = current_user.admin? && action_name == "show" ? Match.all : Match.where(season: active_season)
      @match = scope.find(params[:match_id])
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

    def persist_forecast!
      ForecastSubmissionService.new(
        forecast: @forecast,
        scorer_ids: @selected_scorer_ids,
        assist_player_ids: @selected_assist_ids,
        no_assist: @selected_no_assist
      ).call
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
