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
    assert_equal 0, @user.gold_points_balance(@season)
    MatchConfirmationService.new(match_result: result, admin: @admin).confirm!
    assert_equal 3, @user.gold_points_balance(@season)
    assert_equal 1, forecast.reload.forecast_score.placement
    assert_equal 1, GoldPointTransaction.placement.where(match: @match).count
  end

  test "rollback with unbacked remaining reservations is atomic" do
    @match.update!(kickoff_at: 1.day.ago)
    make_forecast
    result = draft_result
    MatchConfirmationService.new(match_result: result, admin: @admin).confirm!
    make_forecast(match: make_match, gold_points_stake: 3)
    assert_raises(MatchRollbackService::Error) do
      MatchRollbackService.new(season: @season, keep_through_number: 0, admin: @admin).call!
    end
    assert result.reload.confirmed?
    assert_equal 3, @user.gold_points_balance(@season)
    assert_equal 3, @user.reserved_gold_points(@season)
    assert_equal 1, StandingSnapshot.count
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
    assert_equal 23, @user.gold_points_balance(@season)
    assert @user.achievements.exists?(achievement.id)
    forecasts.each { |forecast| assert Forecast.exists?(forecast.id) }
    results.each { |result| assert result.reload.draft? }
    assert_empty @season.standing_snapshots
    results.each { |result| MatchConfirmationService.new(match_result: result, admin: @admin).confirm! }
    assert_equal 29, @user.gold_points_balance(@season)
    assert_equal 1, @user.user_achievements.where(achievement: achievement).count
  end
end
