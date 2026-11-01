module Admin
  class DashboardController < BaseController
    def index
      @season = active_season
      @upcoming_matches = @season ? @season.matches.order(:kickoff_at).limit(8) : Match.none
      @users_count = User.count
      @players_count = Player.active.count
    end
  end
end
