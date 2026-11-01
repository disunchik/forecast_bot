class LegacySetupsController < ApplicationController
  skip_before_action :ensure_legacy_setup_complete

  def edit
    @user = current_user
  end

  def update
    @user = current_user
    unless @user.needs_legacy_setup?
      redirect_to profile_path
      return
    end
    if legacy_params[:password].blank?
      @user.errors.add(:password, "укажите новый пароль")
      render :edit, status: :unprocessable_entity
      return
    end
    if @user.update(legacy_params.merge(legacy_account: false, must_change_password: false))
      @user.sessions.where.not(id: Current.session.id).destroy_all
      redirect_to root_path, notice: "Аккаунт перенесён. Новый пароль сохранён."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  private
    def legacy_params
      params.require(:user).permit(:email_address, :password, :password_confirmation)
    end
end
