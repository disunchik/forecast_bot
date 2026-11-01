require "test_helper"

class ForecastCalculatorTest < ActiveSupport::TestCase
  setup do
    @season = Season.create!(name: "Test season", active: true)
    @competition = Competition.create!(name: "Test competition")
    @match = Match.create!(season: @season, competition: @competition, forecast_number: 1, opponent: "Inter", venue: :home, kickoff_at: 1.day.from_now)
    @user = users(:one)
    @scorer = Player.create!(name: "Scorer")
    @assistant = Player.create!(name: "Assistant")
  end

  test "exact prediction stacks difference exact outcome scorer assist and gold points" do
    forecast = @user.forecasts.create!(
      match: @match,
      halftime_roma: 1,
      halftime_opponent: 0,
      fulltime_roma: 2,
      fulltime_opponent: 0,
      first_score: :roma,
      gold_points_stake: 8,
      submitted_at: Time.current
    )
    forecast.forecast_scorers.create!(player: @scorer)
    forecast.forecast_assists.create!(player: @assistant)

    result = @match.create_match_result!(
      halftime_roma: 1,
      halftime_opponent: 0,
      fulltime_roma: 2,
      fulltime_opponent: 0,
      first_score: :roma,
      state: :draft
    )
    2.times do |index|
      result.goals.create!(scorer: @scorer, assist: @assistant, position: index)
    end

    points = ForecastCalculator.new(forecast: forecast, match_result: result).calculate

    assert_equal 4, points[:halftime_difference_points] + points[:halftime_exact_points]
    assert_equal 8, points[:fulltime_difference_points] + points[:fulltime_exact_points]
    assert_equal 2, points[:outcome_points]
    assert_equal 1, points[:first_score_points]
    assert_equal 6, points[:scorer_points]
    assert_equal 4, points[:assist_points]
    assert_equal 25, points[:base_points]
    assert_equal 8, points[:gold_points_applied]
    assert_equal 33, points[:total_points]
  end

  test "zero zero bonuses are additional" do
    forecast = @user.forecasts.create!(
      match: @match,
      halftime_roma: 0,
      halftime_opponent: 0,
      fulltime_roma: 0,
      fulltime_opponent: 0,
      first_score: :nobody,
      gold_points_stake: 0,
      submitted_at: Time.current
    )
    result = @match.create_match_result!(
      halftime_roma: 0,
      halftime_opponent: 0,
      fulltime_roma: 0,
      fulltime_opponent: 0,
      first_score: :nobody,
      state: :draft
    )

    points = ForecastCalculator.new(forecast: forecast, match_result: result).calculate

    assert_equal 1, points[:roma_no_goal_points]
    assert_equal 2, points[:nil_nil_points]
    assert_equal 18, points[:base_points]
  end

  test "no assist selection scores once for every real goal without assist" do
    forecast = @user.forecasts.create!(
      match: @match,
      halftime_roma: 0,
      halftime_opponent: 0,
      fulltime_roma: 2,
      fulltime_opponent: 0,
      first_score: :roma,
      gold_points_stake: 0,
      submitted_at: Time.current
    )
    forecast.forecast_assists.create!(no_assist: true)

    result = @match.create_match_result!(
      halftime_roma: 0,
      halftime_opponent: 0,
      fulltime_roma: 2,
      fulltime_opponent: 0,
      first_score: :roma,
      state: :draft
    )
    2.times do |index|
      result.goals.create!(scorer: @scorer, no_assist: true, position: index)
    end

    points = ForecastCalculator.new(forecast: forecast, match_result: result).calculate
    assert_equal 4, points[:assist_points]
  end
end
