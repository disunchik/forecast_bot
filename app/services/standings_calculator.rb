class StandingsCalculator
  def initialize(match:)
    @match = match
    @season = match.season
  end

  def rebuild_snapshot!
    snapshot = StandingSnapshot.find_or_initialize_by(match: @match)
    snapshot.season = @season
    snapshot.save!
    snapshot.entries.destroy_all

    users = participating_users
    if @match.forecast_number <= 10
      build_overall(snapshot, users)
    else
      build_split(snapshot, users)
    end

    snapshot
  end

  private
    def participating_users
      User.joins(forecasts: :match)
          .where(matches: { season_id: @season.id })
          .where("matches.forecast_number <= ?", @match.forecast_number)
          .where.not(matches: { status: Match.statuses[:cancelled] })
          .distinct
          .to_a
    end

    def confirmed_matches
      @confirmed_matches ||= @season.matches
                                    .joins(:match_result)
                                    .where(match_results: { state: MatchResult.states[:confirmed] })
                                    .where("matches.forecast_number <= ?", @match.forecast_number)
                                    .order(:forecast_number)
                                    .to_a
    end

    def score_for(user, match)
      @score_cache ||= {}
      @score_cache[[user.id, match.id]] ||= begin
        ForecastScore.joins(:forecast)
                     .find_by(forecasts: { user_id: user.id, match_id: match.id })
                     &.total_points.to_i
      end
    end

    def top_ten_points(user)
      latest_matches = confirmed_matches.last(7)
      older_matches = confirmed_matches.first([confirmed_matches.length - latest_matches.length, 0].max)
      latest_points = latest_matches.sum { |match| score_for(user, match) }
      best_older = older_matches.map { |match| score_for(user, match) }.sort.reverse.first(3).sum
      latest_points + best_older
    end

    def challenger_points(user)
      confirmed_matches.last(3).sum { |match| score_for(user, match) }
    end

    def current_match_score(user)
      score_for(user, @match)
    end

    def current_match_placement(user)
      score = ForecastScore.joins(:forecast).find_by(forecasts: { user_id: user.id, match_id: @match.id })
      score&.placement || 1_000_000
    end

    def last_forecast_time(user)
      user.forecasts.joins(:match)
          .where(matches: { season_id: @season.id })
          .where("matches.forecast_number <= ?", @match.forecast_number)
          .maximum(:updated_at) || Time.at(0)
    end

    def build_overall(snapshot, users)
      ranked = users.sort_by do |user|
        [-top_ten_points(user), current_match_placement(user), -user.gold_points_balance(@season), last_forecast_time(user).to_f]
      end

      ranked.each_with_index do |user, index|
        snapshot.entries.create!(
          user: user,
          group_name: :overall,
          rank: index + 1,
          points: top_ten_points(user),
          last_match_points: current_match_score(user)
        )
      end
    end

    def build_split(snapshot, users)
      previous = previous_snapshot
      previous_top_ids = if previous&.entries&.top_ten&.exists?
                           previous.entries.top_ten.order(:rank).pluck(:user_id)
                         elsif previous
                           previous.entries.overall.order(:rank).limit(10).pluck(:user_id)
                         else
                           users.sort_by { |u| -top_ten_points(u) }.first(10).map(&:id)
                         end

      previous_top_ids &= users.map(&:id)
      previous_challengers = users.reject { |u| previous_top_ids.include?(u.id) }
      winner_id = ForecastScore.joins(:forecast).find_by(forecasts: { match_id: @match.id }, placement: 1)&.forecast&.user_id
      winner = users.find { |u| u.id == winner_id }
      challenger_leader = previous_challengers.min_by { |u| [-challenger_points(u), current_match_placement(u), last_forecast_time(u).to_f] }

      newcomers = []
      newcomers << winner if winner && !previous_top_ids.include?(winner.id)
      newcomers << challenger_leader if challenger_leader && !newcomers.include?(challenger_leader)

      top_users = users.select { |u| previous_top_ids.include?(u.id) } + newcomers
      slots_to_remove = [top_users.size - [10, users.size].min, 0].max

      if slots_to_remove.positive?
        removable = top_users.reject { |u| newcomers.include?(u) }
        worst = removable.sort_by do |user|
          [top_ten_points(user), -current_match_placement(user), user.gold_points_balance(@season), -last_forecast_time(user).to_f]
        end.first(slots_to_remove)
        top_users -= worst
      end

      if top_users.size < [10, users.size].min
        extras = users.reject { |u| top_users.include?(u) }
                      .sort_by { |u| [-challenger_points(u), current_match_placement(u), last_forecast_time(u).to_f] }
                      .first([10, users.size].min - top_users.size)
        top_users += extras
      end

      top_ranked = top_users.sort_by do |user|
        [-top_ten_points(user), current_match_placement(user), -user.gold_points_balance(@season), last_forecast_time(user).to_f]
      end
      challengers = users.reject { |u| top_users.include?(u) }.sort_by do |user|
        [-challenger_points(user), current_match_placement(user), last_forecast_time(user).to_f]
      end

      top_ranked.each_with_index do |user, index|
        snapshot.entries.create!(user: user, group_name: :top_ten, rank: index + 1, points: top_ten_points(user), last_match_points: current_match_score(user))
      end
      challengers.each_with_index do |user, index|
        snapshot.entries.create!(user: user, group_name: :challenger, rank: index + 1, points: challenger_points(user), last_match_points: current_match_score(user))
      end
    end

    def previous_snapshot
      StandingSnapshot.joins(:match)
                      .where(season: @season)
                      .where("matches.forecast_number < ?", @match.forecast_number)
                      .order("matches.forecast_number DESC")
                      .first
    end
end
