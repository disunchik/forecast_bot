module Admin
  class AchievementAwardsController < BaseController
    before_action :set_award

    def revocation
      prepare_change(action: "revoke")
    end

    def restoration
      prepare_change(action: "restore")
      render :revocation
    end

    def revoke
      change_award(action: "revoke")
    end

    def restore
      change_award(action: "restore")
    end

    private
      def set_award
        @achievement = Achievement.find(params[:achievement_id])
        @award = @achievement.user_achievements.includes(:user).find(params[:id])
        @management = AchievementAwardManagementService.new(award: @award, admin: current_user)
      end

      def prepare_change(action:)
        @restoring = action == "restore"
        @state_token = @management.token(action: action)
      end

      def change_award(action:)
        @management.public_send("#{action}!", token: params[:state_token], confirmation: params[:confirmation])
        redirect_to admin_achievement_path(@achievement), notice: action == "revoke" ? "Ачивка отозвана. ЗБ сохранены." : "Ачивка восстановлена без повторного начисления ЗБ."
      rescue AchievementAwardManagementService::Error, AdminStateToken::Error => e
        @error = e.message
        prepare_change(action: action)
        render :revocation, status: :unprocessable_entity
      end
  end
end
