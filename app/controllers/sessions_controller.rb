class SessionsController < ApplicationController
  allow_unauthenticated_access only: %i[new create]
  skip_before_action :ensure_legacy_setup_complete, only: %i[new create destroy]
  rate_limit to: 10, within: 3.minutes, only: :create, with: -> { redirect_to new_session_path, alert: "Слишком много попыток. Попробуйте позже." }

  def new
  end

  def create
    nickname = params[:nickname].to_s
    user = User.find_by(nickname_key: User.nickname_key_for(nickname))

    if user&.authenticate(params[:password])
      start_new_session_for(user)
      redirect_to(user.needs_legacy_setup? ? edit_legacy_setup_path : after_authentication_url)
    else
      redirect_to new_session_path, alert: "Неверный никнейм или пароль."
    end
  end

  def destroy
    terminate_session if Current.session
    redirect_to new_session_path, status: :see_other
  end
end
