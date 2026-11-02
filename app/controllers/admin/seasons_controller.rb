module Admin
  class SeasonsController < BaseController
    before_action :set_season, only: %i[show activate rollback rollback_preview]

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
        Season.where(id: @season.id).update_all("id = id")
        pending = Match.joins(:season, :forecasts).left_joins(:match_result)
                       .where(seasons: { active: true }).where.not(season_id: @season.id).where.not(status: :cancelled)
                       .where("match_results.id IS NULL OR match_results.state = ?", MatchResult.states[:draft]).distinct
        if pending.exists?
          @season.errors.add(:base, "Сначала завершите или удалите матчи текущего сезона с нерассчитанными прогнозами")
          redirect_to admin_seasons_path, alert: @season.errors.full_messages.to_sentence
          return
        end
        Season.where.not(id: @season.id).update_all(active: false)
        @season.update!(active: true)
      end
      redirect_to admin_seasons_path, notice: "Активный сезон изменён."
    end

    def rollback
      number = rollback_number
      MatchRollbackService.new(season: @season, keep_through_number: number, admin: current_user).confirm!(
        token: params[:state_token], reason: params[:reason], confirmation: params[:confirmation]
      )
      notice = params[:before_first] == "1" ? "Все результаты сезона откатились." : "Результаты после матча №#{number} откатились."
      redirect_to admin_season_path(@season), notice: notice
    rescue MatchRollbackService::Error, AdminStateToken::Error, ArgumentError => e
      redirect_to admin_season_path(@season), alert: e.message
    end

    def rollback_preview
      @number = Integer(rollback_number.to_s, 10)
      @rollback = MatchRollbackService.new(season: @season, keep_through_number: @number, admin: current_user)
      @state_token = @rollback.token
    rescue ArgumentError => e
      redirect_to admin_season_path(@season), alert: "Некорректный номер матча: #{e.message}"
    end

    private
      def rollback_number
        params[:before_first] == "1" ? (@season.matches.minimum(:forecast_number) || 1) - 1 : params[:keep_through_number]
      end

      def set_season
        @season = Season.find(params[:id])
      end

      def season_params
        params.require(:season).permit(:name)
      end
  end
end
