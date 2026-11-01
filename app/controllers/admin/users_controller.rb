module Admin
  class UsersController < BaseController
    before_action :set_user, only: %i[show edit update]

    def index
      @query = params[:q].to_s.strip
      @users = User.order(:nickname)
      if @query.present?
        pattern = "%#{ActiveRecord::Base.sanitize_sql_like(User.nickname_key_for(@query))}%"
        @users = @users.where("nickname_key LIKE ? OR email_address LIKE ?", pattern, pattern)
      end
    end

    def show
      @transactions = active_season ? @user.gold_point_transactions.where(season: active_season).order(created_at: :desc) : GoldPointTransaction.none
      @forecasts = active_season ? @user.forecasts.joins(:match).where(matches: { season_id: active_season.id }).includes(:match, :forecast_score).order("matches.forecast_number DESC") : Forecast.none
    end

    def edit
    end

    def update
      attrs = user_params.to_h
      attrs.delete("password") if attrs["password"].blank?
      attrs.delete("password_confirmation") if attrs["password_confirmation"].blank?
      new_role = params.require(:user)[:role].presence
      if new_role && !User.roles.key?(new_role)
        @user.errors.add(:role, "неизвестная роль")
        render :edit, status: :unprocessable_entity
        return
      end
      attrs["role"] = new_role if new_role

      if @user.admin? && new_role == "user" && User.admin.count == 1
        @user.errors.add(:role, "нельзя снять роль у последнего администратора")
        render :edit, status: :unprocessable_entity
        return
      end

      before = @user.slice(:nickname, :email_address, :role)
      User.transaction do
        if @user.update(attrs)
          if attrs.key?("password")
            scope = @user.sessions
            scope = scope.where.not(id: Current.session.id) if @user == current_user
            scope.destroy_all
          end
          AuditLogger.record!(admin: current_user, action: "user.update", auditable: @user, details: { before: before, after: @user.slice(:nickname, :email_address, :role), password_reset: attrs.key?("password") })
          redirect_to admin_user_path(@user), notice: "Пользователь обновлён."
        else
          render :edit, status: :unprocessable_entity
        end
      end
    end

    private
      def set_user
        @user = User.find(params[:id])
      end

      def user_params
        params.require(:user).permit(:nickname, :email_address, :password, :password_confirmation)
      end
  end
end
