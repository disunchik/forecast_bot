module Admin
  class SeasonsController < BaseController
    before_action :set_season, only: %i[show activate rollback]

    def index
      @seasons = Season.order(created_at: :desc)
    end

    def show
      @matches = @season.matches.order(:forecast_number)
    end

    def new
      @season = Season.new
    end

    def create
      @season = Season.new(season_params)
      if @season.save
        redirect_to admin_season_path(@season), notice: "Сезон создан."
      else
        render :new, status: :unprocessable_entity
      end
    end

    def activate
      ActiveRecord::Base.transaction do
        Season.update_all(active: false)
        @season.update!(active: true)
      end
      redirect_to admin_seasons_path, notice: "Активный сезон изменён."
    end

    def rollback
      MatchRollbackService.new(season: @season, keep_through_number: params[:keep_through_number], admin: current_user).call!
      redirect_to admin_season_path(@season), notice: "Результаты после матча №#{params[:keep_through_number]} откатились."
    end

    private
      def set_season
        @season = Season.find(params[:id])
      end

      def season_params
        params.require(:season).permit(:name)
      end
  end
end
