class ProfilesController < ApplicationController
  def show
    @user = current_user
    @transactions = active_season ? @user.gold_point_transactions.where(season: active_season).order(created_at: :desc).limit(100) : GoldPointTransaction.none
    @forecasts = active_season ? @user.forecasts.joins(:match).where(matches: { season_id: active_season.id }).includes(:match, :forecast_score).order("matches.forecast_number DESC") : Forecast.none
    @achievements = Achievement.where(active: true).or(Achievement.where(id: @user.achievement_ids)).order(:name)
  end

  def edit
    @user = current_user
  end

  def update
    @user = current_user
    attrs = profile_params.to_h
    attrs.delete("password") if attrs["password"].blank?
    attrs.delete("password_confirmation") if attrs["password_confirmation"].blank?

    password_changed = attrs.key?("password")
    if @user.update(attrs)
      @user.sessions.where.not(id: Current.session.id).destroy_all if password_changed
      redirect_to profile_path, notice: "Профиль обновлён."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  private
    def profile_params
      params.require(:user).permit(:email_address, :password, :password_confirmation, :notify_forecast_open, :notify_forecast_reminder, :notify_results, :notify_rewards)
    end
end
