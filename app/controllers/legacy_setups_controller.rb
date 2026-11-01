class LegacySetupsController < ApplicationController
  skip_before_action :ensure_legacy_setup_complete

  def edit
    @user = current_user
  end

  def update
    @user = current_user
    if @user.update(legacy_params.merge(legacy_account: false, must_change_password: false))
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
