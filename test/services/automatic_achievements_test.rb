require "test_helper"
require_relative "../support/domain_test_helper"

class AutomaticAchievementsTest < ActiveSupport::TestCase
  include DomainTestHelper
  setup { setup_domain }

  def confirm(match = @match)
    match.update!(kickoff_at: 1.day.ago) if match.kickoff_at > Time.current
    result = draft_result(match: match)
    MatchConfirmationService.new(match_result: result, admin: @admin).confirm!
    result
  end

  def rule_recipients(key, match: @match, **attrs)
    achievement = Achievement.new(name: key, rule_key: key, **attrs)
    context = AchievementRules::Context.new(season: @season, match: match)
    AchievementRules::RULES.fetch(key).last.recipients(context, achievement)
  end

  test "exact derby grants every first recipient the full reward and later recipients one" do
    achievement = Achievement.create!(name: "Романист", rule_key: "derby_exact", secret: true, description: "SECRET DERBY")
    manual = Achievement.create!(name: "Manual")
    archived = Achievement.create!(name: "Archived", rule_key: "derby_exact", active: false)
    @match.update!(opponent: "S.S. Lazio")
    [ @user, @other_user ].each { |user| make_forecast(user: user) }
    confirm
    assert_equal [ @user.id, @other_user.id ].sort, achievement.user_achievements.pluck(:user_id).sort
    assert_equal [ 5, 5 ], GoldPointTransaction.where(achievement: achievement).order(:amount).pluck(:amount)
    assert_not achievement.reload.revealed?
    assert_empty manual.user_achievements
    assert_empty archived.user_achievements
    assert_no_difference [ "UserAchievement.count", "GoldPointTransaction.count" ] do
      AutomaticAchievementsService.for_match!(match: @match, admin: @admin)
    end
    later = make_match(opponent: "Лацио")
    make_forecast(user: @admin, match: later)
    confirm(later)
    assert_equal 1, GoldPointTransaction.find_by!(achievement: achievement, user: @admin).amount
    assert_equal 1, achievement.reload.first_award_round
    assert_equal "automatic_match", AuditLog.where(action: "achievement.award").last.details["source"]
  end

  test "late confirmation checks rebuilt tables without backdating the first cohort" do
    achievement = Achievement.create!(name: "Postponed derby", rule_key: "derby_exact", secret: true)
    @match.update!(status: :postponed, opponent: "Лацио")
    later = make_match(opponent: "Лацио")
    make_forecast(match: later)
    confirm(later)
    assert_equal 2, achievement.reload.first_award_round
    @match.update!(status: :scheduled, kickoff_at: 2.days.ago)
    make_forecast(user: @other_user)
    confirm
    assert_equal [ 5, 5 ], GoldPointTransaction.where(achievement: achievement).order(:amount).pluck(:amount)
    assert_equal 2, achievement.reload.first_award_round
    assert_equal 2, @season.standing_snapshots.count
    assert_not achievement.revealed?
  end

  test "ordinary exact awards require an exact score and the configured competition" do
    wrong_competition = Competition.create!(name: "Other Cup")
    achievement = Achievement.create!(name: "Cup winner", rule_key: "europe_exact", competition_ids: [ @competition.id ])
    make_forecast
    make_forecast(user: @other_user, fulltime_roma: 1, first_score: :roma)
    confirm
    assert achievement.user_achievements.exists?(user: @user)
    assert_not achievement.user_achievements.exists?(user: @other_user)
    assert_equal 3, GoldPointTransaction.find_by!(achievement: achievement).amount
    later = make_match(competition: wrong_competition)
    make_forecast(user: @other_user, match: later)
    confirm(later)
    assert_not achievement.user_achievements.exists?(user: @other_user)
    assert_not Achievement.new(name: "Bad rule", rule_key: "eval").valid?
    assert_not Achievement.new(name: "No cups", rule_key: "europe_exact").valid?
    assert_not AchievementRules.keys.include?("achievement_hunter")
  end

  test "five match wins are counted within one season and awarded only once" do
    achievement = Achievement.create!(name: "Тыж Прогнозист", rule_key: "five_wins")
    5.times do |i|
      match = i.zero? ? @match : make_match
      make_forecast(match: match)
      confirm(match)
      assert_equal(i == 4 ? 1 : 0, achievement.user_achievements.count)
    end
    assert_equal 3, GoldPointTransaction.find_by!(achievement: achievement).amount
    latest = @season.matches.order(:forecast_number).last
    assert_no_difference "UserAchievement.count" do
      AutomaticAchievementsService.for_match!(match: latest, admin: @admin)
    end
  end

  test "disclosure occurs when next forecasts open and remains permanent after postponement" do
    confirm
    achievement = Achievement.create!(name: "Secret", secret: true)
    GoldPointsService.award_achievement!(user: @user, achievement: achievement, admin: @admin)
    next_match = make_match(kickoff: 4.days.from_now.change(usec: 0))
    travel_to next_match.forecast_opens_at - 1.second do
      AchievementRevealService.call
      assert_not achievement.reload.revealed?
    end
    travel_to next_match.forecast_opens_at do
      AchievementRevealService.call
      assert achievement.reload.revealed?
      assert_no_difference "AuditLog.count" do
        AchievementRevealService.call
      end
    end
    next_match.update!(status: :postponed)
    AchievementRevealService.call
    assert achievement.reload.revealed?
  end

  test "last round secrets are disclosed when forecasts open in next active season" do
    confirm
    achievement = Achievement.create!(name: "Final secret", secret: true)
    GoldPointsService.award_achievement!(user: @user, achievement: achievement, admin: @admin)
    next_season = Season.create!(name: "Next season", active: true)
    @season.update!(active: false)
    next_match = make_match(season: next_season, kickoff: 4.days.from_now.change(usec: 0))
    AchievementRevealService.call
    assert_not achievement.reload.revealed?
    travel_to next_match.forecast_opens_at do
      AchievementRevealService.call
      assert achievement.reload.revealed?
    end
    GoldPointsService.award_achievement!(user: @other_user, achievement: achievement, admin: @admin, season: next_season)
    assert_equal 1, GoldPointTransaction.find_by!(achievement: achievement, user: @other_user).amount
  end

  test "rollback and re-confirmation preserve achievements and never pay a second time" do
    achievement = Achievement.create!(name: "Романист", rule_key: "derby_exact")
    @match.update!(opponent: "Лацио")
    make_forecast
    result = confirm
    original = GoldPointTransaction.where(achievement: achievement).pluck(:id)
    MatchRollbackService.new(season: @season, keep_through_number: 0, admin: @admin).call!
    assert achievement.user_achievements.exists?(user: @user)
    MatchConfirmationService.new(match_result: result.reload, admin: @admin).confirm!
    assert_equal original, GoldPointTransaction.where(achievement: achievement).pluck(:id)
  end

  test "top rules distinguish the overall table from top ten and challengers" do
    confirm
    snapshot = @match.standing_snapshot
    snapshot.entries.create!(user: @user, group_name: :overall, rank: 1, points: 0, last_match_points: 0)
    assert_empty rule_recipients("top_leader")
    assert_empty rule_recipients("top_debut")
    snapshot.entries.first.update!(group_name: :top_ten)
    assert_equal [ @user.id ], rule_recipients("top_leader")
    assert_equal [ @user.id ], rule_recipients("top_debut")
    next_match = make_match
    confirm(next_match)
    next_match.standing_snapshot.entries.create!(user: @user, group_name: :challenger, rank: 1, points: 0, last_match_points: 0)
    next_match.standing_snapshot.entries.create!(user: @other_user, group_name: :top_ten, rank: 1, points: 0, last_match_points: 0)
    assert_equal [ @user.id ], rule_recipients("top_exit", match: next_match)
    assert_equal [ @user.id ], rule_recipients("challenger_leader", match: next_match)
    assert_equal [ @other_user.id ], rule_recipients("season_champion", match: next_match)
  end

  test "dark horse requires an earlier tenth place in top ten in the same season" do
    confirm
    @match.standing_snapshot.entries.create!(user: @user, group_name: :top_ten, rank: 10, points: 0, last_match_points: 0)
    assert_empty rule_recipients("dark_horse")
    later = make_match
    confirm(later)
    later.standing_snapshot.entries.create!(user: @user, group_name: :top_ten, rank: 3, points: 0, last_match_points: 0)
    later.standing_snapshot.entries.create!(user: @other_user, group_name: :top_ten, rank: 1, points: 0, last_match_points: 0)
    assert_equal [ @user.id ], rule_recipients("dark_horse", match: later)
  end

  test "head hunter counts three distinct promotions which displace top ten members" do
    7.times do |i|
      match = i.zero? ? @match : make_match
      confirm(match)
      promoted = i.odd?
      match.standing_snapshot.entries.create!(user: @user, group_name: promoted ? :top_ten : :challenger, rank: 1, points: 0, last_match_points: 0)
      match.standing_snapshot.entries.create!(user: @other_user, group_name: promoted ? :challenger : :top_ten, rank: 1, points: 0, last_match_points: 0)
      expected = i == 6 ? [ @user.id, @other_user.id ].sort : (i == 5 ? [ @user.id ] : [])
      assert_equal expected, rule_recipients("three_promotions", match: match).sort
    end
  end

  test "player mentions never combine scorer assist or season periods" do
    player = Player.create!(name: "Quota player")
    12.times do |i|
      match = i.zero? ? @match : make_match
      forecast = make_forecast(match: match, fulltime_roma: 1, first_score: :roma)
      forecast.forecast_scorers.create!(player: player)
      forecast.forecast_assists.create!(player: player)
      confirm(match)
    end
    assert_empty rule_recipients("player_limit")
    second_period = make_match(number: 20)
    forecast = make_forecast(match: second_period, fulltime_roma: 1, first_score: :roma)
    forecast.forecast_scorers.create!(player: player)
    confirm(second_period)
    assert_empty rule_recipients("player_limit", match: second_period)
    thirteenth = make_match(number: 13, kickoff: 1.day.ago)
    forecast = make_forecast(match: thirteenth, fulltime_roma: 1, first_score: :roma)
    forecast.forecast_scorers.create!(player: player)
    confirm(thirteenth)
    assert_equal [ @user.id ], rule_recipients("player_limit", match: thirteenth)
  end
end
