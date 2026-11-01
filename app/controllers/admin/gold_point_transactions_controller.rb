module Admin
  class GoldPointTransactionsController < BaseController
    def index
      @season = params[:season_id].present? ? Season.find(params[:season_id]) : active_season
      @users = User.order(:nickname)
      @transactions = @season ? GoldPointTransaction.where(season: @season).includes(:user).order(created_at: :desc) : GoldPointTransaction.none
    end

    def create
      user = User.find(params[:user_id])
      GoldPointsService.manual!(
        user: user,
        season: active_season,
        amount: params[:amount],
        note: params[:note],
        admin: current_user
      )
      redirect_to admin_user_path(user), notice: "Операция ЗБ добавлена."
    rescue GoldPointsService::Error, ActiveRecord::RecordInvalid => e
      redirect_to admin_user_path(user), alert: e.message
    end
  end
end
