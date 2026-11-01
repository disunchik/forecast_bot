module Admin
  class PlayersController < BaseController
    before_action :set_player, only: %i[edit update archive restore destroy]

    def index
      @tab = params[:tab].in?(%w[active inactive]) ? params[:tab] : "active"
      @players = @tab == "inactive" ? Player.inactive : Player.active
      @active_count = Player.active.count
      @inactive_count = Player.inactive.count
    end

    def new
      @player = Player.new
    end

    def create
      @player = Player.new(player_params)
      if @player.save
        redirect_to admin_players_path, notice: "Игрок добавлен."
      else
        render :new, status: :unprocessable_entity
      end
    end

    def edit
    end

    def update
      if @player.update(player_params)
        redirect_to admin_players_path(tab: @player.active? ? "active" : "inactive"), notice: "Игрок обновлён."
      else
        render :edit, status: :unprocessable_entity
      end
    end

    def archive
      @player.update!(active: false)
      redirect_to admin_players_path(tab: "inactive"), notice: "Игрок перенесён в неактивные."
    end

    def restore
      @player.update!(active: true)
      redirect_to admin_players_path, notice: "Игрок возвращён в активные."
    end

    def destroy
      if @player.forecast_scorers.exists? || @player.forecast_assists.exists? || @player.scored_match_goals.exists? || @player.assisted_match_goals.exists?
        redirect_to admin_players_path, alert: "Использованного игрока нельзя удалить. Переведите его в неактивные."
      else
        @player.destroy!
        redirect_to admin_players_path, notice: "Игрок удалён."
      end
    end

    private
      def set_player
        @player = Player.find(params[:id])
      end

      def player_params
        params.require(:player).permit(:name)
      end
  end
end
