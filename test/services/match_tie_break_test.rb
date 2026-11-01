require "test_helper"
require_relative "../support/domain_test_helper"

class MatchTieBreakTest < ActiveSupport::TestCase
  include DomainTestHelper
  setup do
    setup_domain
    @match.update!(kickoff_at: 1.day.ago)
    @player = Player.create!(name: "Goal author")
    @assistant = Player.create!(name: "Assist author")
    @result = draft_result(halftime_roma: 1, fulltime_roma: 2, fulltime_opponent: 1, first_score: :roma)
    2.times { |i| @result.goals.create!(scorer: @player, assist: @assistant, position: i) }
  end

  {
    "fulltime before halftime" => [ { halftime_roma: 0, halftime_opponent: 1 }, { fulltime_roma: 3, fulltime_opponent: 2 } ],
    "halftime before first goal" => [ { first_score: :opponent }, { halftime_roma: 2, halftime_opponent: 1, gold_points_stake: 1 } ],
    "first goal before outcome" => [ { fulltime_roma: 2, fulltime_opponent: 3, gold_points_stake: 1 }, { fulltime_roma: 4, fulltime_opponent: 2, first_score: :opponent } ],
    "outcome before scorer" => [ { fulltime_roma: 4, fulltime_opponent: 2, gold_points_stake: 1 }, { fulltime_roma: 2, fulltime_opponent: 3 } ],
    "scorer before assist" => [ {}, { gold_points_stake: 2 } ],
    "assist before temporary answer" => [ { temporary_answer_text: "No" }, { temporary_answer_text: "Yes", gold_points_stake: 1 } ],
    "temporary answer before submission time" => [ { temporary_answer_text: "Yes" }, { temporary_answer_text: "No", gold_points_stake: 3 } ]
  }.each do |criterion, (first_attrs, second_attrs)|
    test criterion do
      if criterion.start_with?("temporary", "assist")
        question = @match.create_temporary_question!(text: "Temporary", question_type: :text, points: 3)
        question.accepted_answers.create!(answer_text: "Yes")
      end
      common = { halftime_roma: 1, fulltime_roma: 2, fulltime_opponent: 1, first_score: :roma }
      first = make_forecast(**common.merge(first_attrs), submitted_at: 1.hour.ago)
      second = make_forecast(user: @other_user, **common.merge(second_attrs), submitted_at: 2.hours.ago)
      first.forecast_scorers.create!(player: @player) if criterion.start_with?("scorer")
      first.forecast_assists.create!(player: @assistant) if criterion.start_with?("assist")
      if criterion.start_with?("outcome")
        another = Player.create!(name: "Second goal author")
        @result.goals.last.update!(scorer: another)
        second.forecast_scorers.create!(player: @player)
      end
      second.forecast_assists.create!(player: @assistant) if criterion.start_with?("scorer")
      rows = MatchConfirmationService.new(match_result: @result, admin: @admin).preview
      assert_equal rows.first[:values][:total_points], rows.last[:values][:total_points], "Scores must tie to exercise #{criterion}"
      assert_equal [ first.id, second.id ], rows.map { |row| row[:forecast].id }
    end
  end
end
