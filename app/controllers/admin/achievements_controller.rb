module Admin
  class AchievementsController < BaseController
    before_action :set_achievement, only: %i[edit update destroy award]

    def index
      @achievements = Achievement.order(:name)
    end

    def new
      @achievement = Achievement.new
    end

    def create
      @achievement = Achievement.new(achievement_params)
      if @achievement.save
        redirect_to admin_achievements_path, notice: "Ачивка создана."
      else
        render :new, status: :unprocessable_entity
      end
    end

    def edit
    end

    def update
      if @achievement.update(achievement_params)
        redirect_to admin_achievements_path, notice: "Ачивка обновлена."
      else
        render :edit, status: :unprocessable_entity
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

      def achievement_params
        params.require(:achievement).permit(:name, :description, :secret, :active)
      end
  end
end
