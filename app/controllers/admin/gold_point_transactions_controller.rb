module Admin
  class GoldPointTransactionsController < BaseController
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
