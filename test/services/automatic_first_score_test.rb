require "test_helper"
require_relative "../support/domain_test_helper"

class AutomaticFirstScoreTest < ActiveSupport::TestCase
  include DomainTestHelper
  setup { setup_domain }

  test "both model types derive forced first goal by team rather than venue" do
    cases = [
      [ 0, 0, 0, 0, "nobody" ], [ 0, 0, 1, 0, "roma" ], [ 0, 0, 0, 1, "opponent" ],
      [ 1, 0, 1, 2, "roma" ], [ 0, 1, 2, 1, "opponent" ]
    ]
    [ :home, :away ].each do |venue|
      @match.update!(venue: venue)
      cases.each do |hr, ho, fr, fo, expected|
        attrs = { halftime_roma: hr, halftime_opponent: ho, fulltime_roma: fr, fulltime_opponent: fo, first_score: :roma }
        forecast = @user.forecasts.new(match: @match, submitted_at: Time.current, **attrs)
        result = @match.build_match_result(**attrs)
        [ forecast, result ].each do |record|
          assert record.valid?, record.errors.full_messages.inspect
          assert_equal expected, record.first_score
        end
      end
    end
  end

  test "ambiguous result requires a manual first goal" do
    forecast = @user.forecasts.new(match: @match, submitted_at: Time.current,
                                  halftime_roma: 0, halftime_opponent: 0, fulltime_roma: 1, fulltime_opponent: 1)
    assert_not forecast.valid?
    forecast.first_score = :opponent
    assert forecast.valid?
    assert_equal "opponent", forecast.first_score
  end

  test "automatic first goal does not make invalid halftime acceptable" do
    forecast = @user.forecasts.new(match: @match, submitted_at: Time.current,
                                  halftime_roma: 2, halftime_opponent: 0, fulltime_roma: 0, fulltime_opponent: 1)
    assert_not forecast.valid?
  end
end
