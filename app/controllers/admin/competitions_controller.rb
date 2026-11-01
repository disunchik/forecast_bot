module Admin
  class CompetitionsController < BaseController
    before_action :set_competition, only: %i[edit update]

    def index
      @competitions = Competition.order(:name)
    end

    def new
      @competition = Competition.new(active: true)
    end

    def create
      @competition = Competition.new(competition_params)
      if @competition.save
        redirect_to admin_competitions_path, notice: "Турнир создан."
      else
        render :new, status: :unprocessable_entity
      end
    end

    def edit
    end

    def update
      if @competition.update(competition_params)
        redirect_to admin_competitions_path, notice: "Турнир обновлён."
      else
        render :edit, status: :unprocessable_entity
      end
    end

    private
      def set_competition
        @competition = Competition.find(params[:id])
      end

      def competition_params
        params.require(:competition).permit(:name, :active)
      end
  end
end
