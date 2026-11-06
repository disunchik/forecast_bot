module Admin
  class AchievementsController < BaseController
    before_action :set_achievement, only: %i[show edit update destroy award]

    def index
      AchievementRevealService.call
      @achievements = Achievement.order(:name)
      @achievement_recipient_counts = UserAchievement.current.group(:achievement_id).count
    end

    def new
      @achievement = Achievement.new
    end

    def create
      @achievement = Achievement.new(achievement_params)
      Achievement.transaction do
        if @achievement.save
          AuditLogger.record!(admin: current_user, action: "achievement.create", auditable: @achievement, details: { after: @achievement.attributes })
          redirect_to admin_achievements_path, notice: "Ачивка создана."
        else
          render :new, status: :unprocessable_entity
        end
      end
    end

    def show
      load_recipients
    end

    def edit
      load_recipients
    end

    def update
      Achievement.transaction do
        before = @achievement.attributes
        if @achievement.update(achievement_params)
          AuditLogger.record!(admin: current_user, action: "achievement.update", auditable: @achievement,
                              details: { before: before, after: @achievement.attributes })
          redirect_to admin_achievements_path, notice: "Ачивка обновлена."
        else
          load_recipients
          render :edit, status: :unprocessable_entity
        end
      end
    end

    def destroy
      if @achievement.user_achievements.exists?
        @achievement.update!(active: false)
        redirect_to admin_achievements_path, notice: "Выданная ачивка отключена, но сохранена в истории."
      else
        @achievement.destroy!
        redirect_to admin_achievements_path, notice: "Ачивка удалена."
      end
    end

    def award
      user = User.find(params[:user_id])
      GoldPointsService.award_achievement!(user: user, achievement: @achievement, admin: current_user)
      redirect_to admin_user_path(user), notice: "Ачивка выдана."
    rescue GoldPointsService::Error, ActiveRecord::RecordInvalid => e
      redirect_to admin_user_path(user), alert: e.message
    end

    private
      def set_achievement
        @achievement = Achievement.find(params[:id])
      end

      def load_recipients
        @recipients = @achievement.user_achievements.includes(:user, :awarded_by, :revoked_by).order(awarded_at: :desc, id: :desc).to_a
      end

      def achievement_params
        params.require(:achievement).permit(:name, :description, :secret, :active, :rule_key, competition_ids: [])
      end
  end
end
