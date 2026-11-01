class RegistrationsController < ApplicationController
  allow_unauthenticated_access only: %i[new create]
  skip_before_action :ensure_legacy_setup_complete
  rate_limit to: 5, within: 10.minutes, only: :create, with: -> { redirect_to new_registration_path, alert: "Слишком много попыток регистрации. Попробуйте позже." }

  def new
    @user = User.new
  end

  def create
    @user = User.new(registration_params.merge(role: :user))
    if @user.save
      start_new_session_for(@user)
      redirect_to root_path, notice: "Аккаунт создан."
    else
      render :new, status: :unprocessable_entity
    end
  end

  private
    def registration_params
      params.require(:user).permit(:nickname, :email_address, :password, :password_confirmation)
    end
end
