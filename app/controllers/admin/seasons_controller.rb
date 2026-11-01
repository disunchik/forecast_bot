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
        Season.where.not(id: @season.id).update_all(active: false)
        @season.update!(active: true)
      end
      redirect_to admin_seasons_path, notice: "Активный сезон изменён."
    end

    def rollback
      number = params[:before_first] == "1" ? (@season.matches.minimum(:forecast_number) || 1) - 1 : params[:keep_through_number]
      MatchRollbackService.new(season: @season, keep_through_number: number, admin: current_user).call!
      notice = params[:before_first] == "1" ? "Все результаты сезона откатились." : "Результаты после матча №#{number} откатились."
      redirect_to admin_season_path(@season), notice: notice
    rescue MatchRollbackService::Error, ArgumentError => e
      redirect_to admin_season_path(@season), alert: e.message
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
