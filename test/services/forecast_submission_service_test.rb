require "test_helper"
require_relative "../support/domain_test_helper"

class ForecastSubmissionServiceTest < ActiveSupport::TestCase
  include DomainTestHelper
  setup { setup_domain }

  test "opens exactly at minus 48 hours and closes exactly at minus 2" do
    @match.update!(kickoff_at: @match.kickoff_at.change(usec: 0))
    [ [ -48.hours - 1.second, false ], [ -48.hours, true ], [ -2.hours - 1.second, true ], [ -2.hours, false ] ].each do |offset, expected|
      travel_to(@match.kickoff_at + offset) do
        forecast = @user.forecasts.new(match: @match, **forecast_attributes)
        assert_equal expected, ForecastSubmissionService.new(forecast: forecast).call
        forecast.destroy! if forecast.persisted?
      end
    end
  end

  test "rechecks deadline and current match state when persisting" do
    forecast = @user.forecasts.new(match: @match, **forecast_attributes)
    @match.update!(kickoff_at: 1.hour.from_now)
    assert_not ForecastSubmissionService.new(forecast: forecast).call
    assert_not forecast.persisted?
  end

  test "two open matches cannot reserve the same balance" do
    fund(amount: 5)
    first = @user.forecasts.new(match: @match, **forecast_attributes(gold_points_stake: 5))
    second = @user.forecasts.new(match: make_match, **forecast_attributes(gold_points_stake: 1))
    assert ForecastSubmissionService.new(forecast: first).call
    assert_not ForecastSubmissionService.new(forecast: second).call
    assert_equal 5, @user.reserved_gold_points(@season)
  end

  test "editing a forecast releases the old reservation" do
    fund(amount: 5)
    forecast = make_forecast(gold_points_stake: 5)
    forecast.gold_points_stake = 2
    assert ForecastSubmissionService.new(forecast: forecast).call
    assert_equal 3, @user.available_gold_points(@season)
  end

  test "inactive season cannot receive predictions" do
    @season.update!(active: false)
    forecast = @user.forecasts.new(match: @match, **forecast_attributes)
    assert_not ForecastSubmissionService.new(forecast: forecast).call
  end

  test "successful resubmission updates tie break time" do
    forecast = make_forecast(submitted_at: 1.hour.ago)
    old_time = forecast.submitted_at
    assert ForecastSubmissionService.new(forecast: forecast).call
    assert_operator forecast.reload.submitted_at, :>, old_time
    assert_equal 1, @user.forecasts.where(match: @match).count
  end

  test "unknown inactive and too many players are rejected" do
    inactive = Player.create!(name: "Inactive", active: false)
    [ [ inactive.id ], [ 999999 ] ].each do |ids|
      forecast = @user.forecasts.new(match: @match, **forecast_attributes(fulltime_roma: 1, first_score: "roma"))
      assert_not ForecastSubmissionService.new(forecast: forecast, scorer_ids: ids).call
    end
    players = 9.times.map { |i| Player.create!(name: "Player #{i}") }
    forecast = @user.forecasts.new(match: @match, **forecast_attributes(fulltime_roma: 9, first_score: "roma"))
    assert_not ForecastSubmissionService.new(forecast: forecast, scorer_ids: players.map(&:id)).call
  end

  test "empty scorer and assist selections are allowed" do
    forecast = @user.forecasts.new(match: @match, **forecast_attributes(fulltime_roma: 3, first_score: "roma"))
    assert ForecastSubmissionService.new(forecast: forecast).call
  end

  test "thirteenth mention succeeds fourteenth fails and removing selection frees it" do
    player = Player.create!(name: "Limited")
    12.times do
      forecast = make_forecast(match: make_match, fulltime_roma: 1, first_score: :roma)
      forecast.forecast_scorers.create!(player: player)
    end
    thirteenth = @user.forecasts.new(match: @match, **forecast_attributes(fulltime_roma: 1, first_score: "roma"))
    assert ForecastSubmissionService.new(forecast: thirteenth, scorer_ids: [ player.id ]).call
    fourteenth = @user.forecasts.new(match: make_match, **forecast_attributes(fulltime_roma: 1, first_score: "roma"))
    assert_not ForecastSubmissionService.new(forecast: fourteenth, scorer_ids: [ player.id ]).call
    assert ForecastSubmissionService.new(forecast: thirteenth, assist_player_ids: [ player.id ]).call
    assert ForecastSubmissionService.new(forecast: fourteenth, scorer_ids: [ player.id ]).call
  end

  test "mention periods split at 20 and seasons are independent" do
    player = Player.create!(name: "Period player")
    (2..14).each do |number|
      make_forecast(match: make_match(number: number), fulltime_roma: 1, first_score: :roma).forecast_scorers.create!(player: player)
    end
    [ 19, 20 ].each do |number|
      match = make_match(number: number)
      limits = PlayerLimitsService.new(user: @user, match: match)
      assert_equal(number == 20, limits.scorer_available?(player))
      assert limits.assist_available?(player)
    end
    other_season = Season.create!(name: "Other")
    assert PlayerLimitsService.new(user: @user, match: make_match(season: other_season)).scorer_available?(player)
  end
end
