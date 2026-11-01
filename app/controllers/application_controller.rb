class ApplicationController < ActionController::Base
  include Authentication

  allow_browser versions: :modern
  stale_when_importmap_changes

  before_action :ensure_legacy_setup_complete

  helper_method :current_user, :active_season

  private
    def require_html_response
      head :not_acceptable unless request.format.html?
    end

    def current_user
      Current.user
    end

    def active_season
      @active_season ||= Season.active.first
    end

    def ensure_legacy_setup_complete
      return unless Current.user&.needs_legacy_setup?
      return if controller_path == "legacy_setups"
      return if controller_path == "sessions" && action_name == "destroy"

      redirect_to edit_legacy_setup_path, alert: "Завершите перенос аккаунта: укажите email и новый пароль."
    end
end
