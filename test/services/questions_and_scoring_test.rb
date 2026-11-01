require "test_helper"
require_relative "../support/domain_test_helper"

class QuestionsAndScoringTest < ActiveSupport::TestCase
  include DomainTestHelper
  setup { setup_domain }

  test "question is required and choice must belong to current match" do
    question = @match.create_temporary_question!(text: "Question", question_type: :choice, points: 5)
    forecast = @user.forecasts.new(match: @match, **forecast_attributes)
    assert_not ForecastSubmissionService.new(forecast: forecast).call
    other_question = make_match.create_temporary_question!(text: "Other", question_type: :choice, points: 5)
    forecast.temporary_question_option = other_question.options.create!(text: "Wrong match")
    assert_not ForecastSubmissionService.new(forecast: forecast).call
    forecast.temporary_question_option = question.options.create!(text: "Right match")
    assert ForecastSubmissionService.new(forecast: forecast).call
  end

  test "multiple choice answers can score and voided question never scores" do
    question = @match.create_temporary_question!(text: "Question", question_type: :choice, points: 5)
    yes = question.options.create!(text: "Yes", correct: true)
    no = question.options.create!(text: "No", correct: true)
    forecasts = [ make_forecast(temporary_question_option: yes), make_forecast(user: @other_user, temporary_question_option: no) ]
    result = draft_result
    forecasts.each { |f| assert_equal 5, ForecastCalculator.new(forecast: f, match_result: result).calculate[:temporary_question_points] }
    question.update!(voided: true)
    forecasts.each do |f|
      assert_equal 0, ForecastCalculator.new(forecast: f.reload, match_result: result).calculate[:temporary_question_points]
    end
  end

  test "text questions normalize case and surrounding spaces and accept multiple answers" do
    question = @match.create_temporary_question!(text: "Question", question_type: :text, points: 7)
    question.accepted_answers.create!(answer_text: "Рома")
    question.accepted_answers.create!(answer_text: "Roma")
    result = draft_result
    [ " РОМА ", " roma " ].each do |answer|
      forecast = make_forecast(temporary_answer_text: answer)
      assert_equal 7, ForecastCalculator.new(forecast: forecast, match_result: result).calculate[:temporary_question_points]
      forecast.destroy!
    end
  end

  test "invalid halftime first score and negative scores are rejected" do
    [ { halftime_roma: 2, fulltime_roma: 1, first_score: "roma" }, { fulltime_opponent: -1 },
      { first_score: "roma" }, { fulltime_roma: 1 } ].each do |attrs|
      forecast = @user.forecasts.new(match: @match, **forecast_attributes(**attrs))
      assert_not ForecastSubmissionService.new(forecast: forecast).call
    end
  end

  [ 1, 4, 5, 6, 7, 8 ].each do |count|
    test "scorer weighting for #{count} selected players counts actual duplicate goals" do
      players = count.times.map { |i| Player.create!(name: "Scorer #{i}") }
      forecast = make_forecast(fulltime_roma: count + 1, first_score: :roma)
      players.each { |p| forecast.forecast_scorers.create!(player: p) }
      result = draft_result(fulltime_roma: 2, first_score: :roma)
      2.times { |i| result.goals.create!(scorer: players.first, no_assist: true, position: i) }
      unit = count <= 4 ? 3 : (count <= 6 ? 2 : 1)
      assert_equal 2 * unit, ForecastCalculator.new(forecast: forecast, match_result: result).calculate[:scorer_points]
    end
  end

  [ 4, 5 ].each do |count|
    test "assist weighting at #{count} selected options" do
      scorer = Player.create!(name: "Scorer")
      players = count.times.map { |i| Player.create!(name: "Assist #{i}") }
      forecast = make_forecast(fulltime_roma: count, first_score: :roma)
      players.each { |p| forecast.forecast_assists.create!(player: p) }
      result = draft_result(fulltime_roma: 1, first_score: :roma)
      result.goals.create!(scorer: scorer, assist: players.first)
      assert_equal(count == 4 ? 2 : 1, ForecastCalculator.new(forecast: forecast, match_result: result).calculate[:assist_points])
    end
  end

  test "own goals do not award scorer or no-assist points" do
    player = Player.create!(name: "Selected")
    forecast = make_forecast(fulltime_roma: 1, first_score: :roma)
    forecast.forecast_scorers.create!(player: player)
    forecast.forecast_assists.create!(no_assist: true)
    result = draft_result(fulltime_roma: 1, first_score: :roma)
    result.goals.create!(own_goal: true)
    points = ForecastCalculator.new(forecast: forecast, match_result: result).calculate
    assert_equal 0, points[:scorer_points]
    assert_equal 0, points[:assist_points]
  end

  test "odd base points cap gold with floor" do
    forecast = make_forecast(gold_points_stake: 20, halftime_roma: 1, fulltime_roma: 1, first_score: :roma)
    result = draft_result(fulltime_roma: 2, first_score: :roma)
    points = ForecastCalculator.new(forecast: forecast, match_result: result).calculate
    assert_equal 3, points[:base_points]
    assert_equal 1, points[:gold_points_applied]
  end
end
