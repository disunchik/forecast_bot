require "test_helper"
require_relative "../support/domain_test_helper"

class MatchLifecycleTest < ActiveSupport::TestCase
  include DomainTestHelper
  setup { setup_domain }

  test "preview and confirmation require deadline even with direct service call" do
    result = draft_result
    service = MatchConfirmationService.new(match_result: result, admin: @admin)
    assert_raises(MatchConfirmationService::Error) { service.preview }
    assert_raises(MatchConfirmationService::Error) { service.confirm! }
    assert_empty GoldPointTransaction.all
  end

  test "preview validates goal count and never awards points" do
    @match.update!(kickoff_at: 1.day.ago)
    make_forecast
    result = draft_result(fulltime_roma: 1, first_score: :roma)
    service = MatchConfirmationService.new(match_result: result, admin: @admin)
    assert_raises(MatchConfirmationService::Error) { service.preview }
    assert_empty ForecastScore.all
    assert_empty GoldPointTransaction.all
  end

  test "confirmation spends entire stake and caps bonus with floor" do
    fund(amount: 20)
    @match.update!(kickoff_at: 1.day.ago)
    forecast = make_forecast(gold_points_stake: 20, halftime_roma: 1, fulltime_roma: 1, first_score: :roma)
    result = draft_result
    MatchConfirmationService.new(match_result: result, admin: @admin).confirm!
    score = forecast.reload.forecast_score
    assert_equal 0, score.base_points
    assert_equal 0, score.gold_points_applied
    assert_equal(-20, GoldPointTransaction.stake.where(match: @match).sum(:amount))
    assert_equal 0, @user.gold_points_balance(@season)
    assert_equal 0, @user.reserved_gold_points(@season)
  end

  test "repeat confirmation and rollback recalculate without duplicate gold" do
    @match.update!(kickoff_at: 1.day.ago)
    forecast = make_forecast
    result = draft_result
    service = MatchConfirmationService.new(match_result: result, admin: @admin)
    before = service.preview
    assert_equal 18, before.first[:values][:total_points]
    assert_empty ForecastScore.all
    service.confirm!
    assert_equal 3, @user.gold_points_balance(@season)
    assert_raises(MatchConfirmationService::Error) { service.confirm! }
    MatchRollbackService.new(season: @season, keep_through_number: 0, admin: @admin).call!
    assert forecast.reload
    assert result.reload.draft?
    assert_equal 3, @user.gold_points_balance(@season)
    MatchConfirmationService.new(match_result: result, admin: @admin).confirm!
    assert_equal 3, @user.gold_points_balance(@season)
    assert_equal 1, forecast.reload.forecast_score.placement
    assert_equal 1, GoldPointTransaction.placement.where(match: @match).count
  end

  test "rollback preserves gold backing accepted stakes and recalculation can finish" do
    @match.update!(kickoff_at: 1.day.ago)
    make_forecast
    result = draft_result
    MatchConfirmationService.new(match_result: result, admin: @admin).confirm!
    later = make_match
    forecast = make_forecast(match: later, gold_points_stake: 3, halftime_roma: 1,
                             halftime_opponent: 0, fulltime_roma: 2, fulltime_opponent: 1, first_score: :roma)
    2.times do
      MatchRollbackService.new(season: @season, keep_through_number: 0, admin: @admin).call!
      assert result.reload.draft?
      assert_equal 3, @user.gold_points_balance(@season)
      assert_equal 3, @user.reserved_gold_points(@season)
      assert_equal 3, forecast.reload.gold_points_stake
      assert_empty @season.standing_snapshots
      MatchConfirmationService.new(match_result: result, admin: @admin).confirm!
    end
    later.update!(kickoff_at: 1.day.ago)
    MatchConfirmationService.new(match_result: draft_result(match: later), admin: @admin).confirm!
    assert_equal 0, @user.gold_points_balance(@season)
    assert_equal 0, @user.reserved_gold_points(@season)
    assert_equal(-3, GoldPointTransaction.stake.where(match: later).sum(:amount))
    assert_equal 1, GoldPointTransaction.placement.where(match: @match, user: @user).count
  end

  test "correction keeps previous reward and only pays increases to new winners" do
    @match.update!(kickoff_at: 1.day.ago)
    make_forecast
    make_forecast(user: @other_user, fulltime_opponent: 1, first_score: :opponent)
    result = draft_result
    MatchConfirmationService.new(match_result: result, admin: @admin).confirm!
    assert_equal 3, @user.gold_points_balance(@season)
    assert_equal 2, @other_user.gold_points_balance(@season)
    2.times do
      MatchRollbackService.new(season: @season, keep_through_number: 0, admin: @admin).call!
      result.reload.update!(fulltime_opponent: 1, first_score: :opponent)
      MatchConfirmationService.new(match_result: result, admin: @admin).confirm!
      assert_equal 3, @user.gold_points_balance(@season)
      assert_equal 3, @other_user.gold_points_balance(@season)
      assert_equal 1, @other_user.forecasts.find_by!(match: @match).forecast_score.placement
    end
    assert_equal [ 2, 1 ], GoldPointTransaction.placement.where(match: @match, user: @other_user).order(:id).pluck(:amount)
  end

  test "zero corrected score does not reclaim a reward backing a later bet" do
    @match.update!(kickoff_at: 1.day.ago)
    forecast = make_forecast(fulltime_opponent: 1, first_score: :opponent)
    result = draft_result(fulltime_opponent: 1, first_score: :opponent)
    MatchConfirmationService.new(match_result: result, admin: @admin).confirm!
    later = make_forecast(match: make_match, gold_points_stake: 3)
    MatchRollbackService.new(season: @season, keep_through_number: 0, admin: @admin).call!
    result.reload.update!(halftime_roma: 1, fulltime_roma: 2, fulltime_opponent: 0, first_score: :roma)
    2.times { |position| result.goals.create!(own_goal: true, position: position) }
    MatchConfirmationService.new(match_result: result, admin: @admin).confirm!
    assert_equal 0, forecast.reload.forecast_score.total_points
    assert_equal 3, @user.gold_points_balance(@season)
    assert_equal 3, @user.reserved_gold_points(@season)
    assert_equal 3, later.reload.gold_points_stake
    assert_equal 3, GoldPointTransaction.placement.where(match: @match, user: @user).sum(:amount)
  end

  test "postponed earlier match does not block later result and later tables are rebuilt" do
    @match.update!(forecast_number: 5, status: :postponed)
    later = make_match(number: 6, kickoff: 1.day.ago)
    make_forecast(match: later)
    later_result = draft_result(match: later)
    MatchConfirmationService.new(match_result: later_result, admin: @admin).confirm!
    assert_equal 18, later.reload.standing_snapshot.entries.find_by!(user: @user).points
    paid_gold = GoldPointTransaction.where(match: later).order(:id).pluck(:id, :amount)
    scores = later_result.forecast_scores.pluck(:id, :total_points)
    @match.update!(status: :scheduled, kickoff_at: 1.day.ago)
    make_forecast
    MatchConfirmationService.new(match_result: draft_result, admin: @admin).confirm!
    assert_equal 36, later.standing_snapshot.entries.find_by!(user: @user).points
    assert_equal 18, @match.reload.standing_snapshot.entries.find_by!(user: @user).points
    assert_equal paid_gold, GoldPointTransaction.where(match: later).order(:id).pluck(:id, :amount)
    assert_equal scores, later_result.forecast_scores.pluck(:id, :total_points)
    assert_equal 6, @user.gold_points_balance(@season)
  end

  test "postponed match itself cannot be confirmed" do
    @match.update!(status: :postponed, kickoff_at: 1.day.ago)
    assert_raises(MatchConfirmationService::Error) do
      MatchConfirmationService.new(match_result: draft_result, admin: @admin).confirm!
    end
    assert_empty ForecastScore.all
  end

  test "cup result drawn after extra time awards draw outcome" do
    @match.update!(kickoff_at: 1.day.ago)
    forecast = make_forecast(fulltime_roma: 1, fulltime_opponent: 1, first_score: :roma)
    result = draft_result(fulltime_roma: 1, fulltime_opponent: 1, first_score: :roma)
    result.goals.create!(position: 1, own_goal: true)
    MatchConfirmationService.new(match_result: result, admin: @admin).confirm!
    score = forecast.reload.forecast_score
    assert_equal 2, score.outcome_points
    assert_equal 4, score.fulltime_exact_points
    assert_equal 4, score.fulltime_difference_points
    assert_equal 1, result.goals.count
  end

  test "saved rules survive edits and rollback" do
    @match.update!(kickoff_at: 1.day.ago)
    forecast = make_forecast
    result = draft_result
    MatchConfirmationService.new(match_result: result, admin: @admin).confirm!
    rule = ScoringRule.find_or_initialize_by(key: "nil_nil")
    rule.update!(label: "0:0", value: 99)
    rule = ScoringRule.find_or_initialize_by(key: "placement_first")
    rule.update!(label: "First", value: 99)
    MatchRollbackService.new(season: @season, keep_through_number: 0, admin: @admin).call!
    MatchConfirmationService.new(match_result: result.reload, admin: @admin).confirm!
    assert_equal 18, forecast.reload.forecast_score.total_points
    assert_equal 3, @user.gold_points_balance(@season)
  end

  test "equal match results use submitted time and then permanent id" do
    @match.update!(kickoff_at: 1.day.ago)
    early = make_forecast(submitted_at: 2.hours.ago)
    late = make_forecast(user: @other_user, submitted_at: 1.hour.ago)
    early.update_column(:updated_at, Time.current)
    result = draft_result
    rows = MatchConfirmationService.new(match_result: result, admin: @admin).preview
    assert_equal [ early.id, late.id ], rows.map { |row| row[:forecast].id }
    late.update_column(:submitted_at, early.submitted_at)
    rows = MatchConfirmationService.new(match_result: result, admin: @admin).preview
    assert_equal [ early.id, late.id ].sort, rows.map { |row| row[:forecast].id }
  end

  test "placement rewards are distinct and only positive scores receive them" do
    @match.update!(kickoff_at: 1.day.ago)
    make_forecast(submitted_at: 2.hours.ago)
    make_forecast(user: @other_user, submitted_at: 1.hour.ago)
    make_forecast(user: @admin)
    MatchConfirmationService.new(match_result: draft_result, admin: @admin).confirm!
    assert_equal [ 1, 2, 3 ], GoldPointTransaction.placement.order(:amount).pluck(:amount)
  end
  test "gold bonus changes match placement and contributes to standings" do
    fund(amount: 20)
    @match.update!(kickoff_at: 1.day.ago)
    forecast = make_forecast(gold_points_stake: 3)
    make_forecast(user: @other_user)
    MatchConfirmationService.new(match_result: draft_result, admin: @admin).confirm!
    assert_equal 21, forecast.reload.forecast_score.total_points
    assert_equal 1, forecast.forecast_score.placement
    assert_equal 21, @match.reload.standing_snapshot.entries.find_by!(user: @user).points
    assert_equal 20, @user.gold_points_balance(@season)
  end

  test "rollback several matches preserves predictions actual events and manual achievements" do
    fund(amount: 20)
    achievement = Achievement.create!(name: "Permanent rollback")
    GoldPointsService.award_achievement!(user: @user, achievement: achievement, admin: @admin)
    @match.update!(kickoff_at: 2.days.ago)
    forecasts = [ make_forecast ]
    results = [ draft_result ]
    MatchConfirmationService.new(match_result: results.first, admin: @admin).confirm!
    second = make_match(kickoff: 1.day.ago)
    forecasts << make_forecast(match: second)
    results << draft_result(match: second)
    MatchConfirmationService.new(match_result: results.last, admin: @admin).confirm!
    MatchRollbackService.new(season: @season, keep_through_number: 0, admin: @admin).call!
    assert_equal 29, @user.gold_points_balance(@season)
    assert @user.achievements.exists?(achievement.id)
    forecasts.each { |forecast| assert Forecast.exists?(forecast.id) }
    results.each { |result| assert result.reload.draft? }
    assert_empty @season.standing_snapshots
    results.each { |result| MatchConfirmationService.new(match_result: result, admin: @admin).confirm! }
    assert_equal 29, @user.gold_points_balance(@season)
    assert_equal 1, @user.user_achievements.where(achievement: achievement).count
  end
end
