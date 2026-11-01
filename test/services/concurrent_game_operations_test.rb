require "test_helper"
require_relative "../support/domain_test_helper"

class ConcurrentGameOperationsTest < ActiveSupport::TestCase
  include DomainTestHelper
  self.use_transactional_tests = false

  setup { setup_domain }
  teardown do
    if @season&.persisted?
      GoldPointTransaction.where(season: @season).delete_all
      @season.matches.destroy_all
      @season.destroy!
    end
    AuditLog.where(admin: @admin).delete_all
    @achievement&.destroy!
    @admin&.destroy!
    @competition&.destroy!
  end

  def race(*operations)
    gate = Queue.new
    results = Queue.new
    threads = operations.map do |operation|
      Thread.new do
        ActiveRecord::Base.connection_pool.with_connection do
          gate.pop
          results << operation.call
        rescue => error
          results << error
        end
      end
    end
    threads.size.times { gate << true }
    threads.each(&:join)
    threads.size.times.map { results.pop }
  end

  test "parallel forecasts serialize balance reservations on SQLite" do
    fund(amount: 5)
    matches = [ @match, make_match ]
    user_id = @user.id
    operations = matches.map do |match|
      -> {
        forecast = User.find(user_id).forecasts.new(match: Match.find(match.id), **forecast_attributes(gold_points_stake: 5))
        ForecastSubmissionService.new(forecast: forecast).call
      }
    end
    results = race(*operations)
    assert_equal [ false, true ], results.sort_by(&:to_s), results.inspect
    assert_equal 5, @user.reserved_gold_points(@season)
    assert_equal 0, @user.available_gold_points(@season)
  end

  test "parallel first secret awards yield only one first reward" do
    @achievement = Achievement.create!(name: "Race #{SecureRandom.hex(4)}", secret: true)
    users = [ @user, @other_user ]
    results = race(*users.map do |user|
      -> { GoldPointsService.award_achievement!(user: User.find(user.id), achievement: Achievement.find(@achievement.id), admin: @admin, season: @season); true }
    end)
    assert_equal [ true, true ], results, results.inspect
    assert_equal [ 1, 5 ], GoldPointTransaction.where(achievement: @achievement).order(:amount).pluck(:amount)
  end

  test "parallel confirmation never duplicates scores or gold" do
    @match.update!(kickoff_at: 1.day.ago)
    make_forecast
    result = draft_result
    operation = -> do
      MatchConfirmationService.new(match_result: MatchResult.find(result.id), admin: @admin).confirm!
      true
    rescue MatchConfirmationService::Error
      false
    end
    results = race(operation, operation)
    assert_equal [ false, true ], results.sort_by(&:to_s), results.inspect
    assert_equal 1, ForecastScore.where(match_result: result).count
    assert_equal 3, @user.gold_points_balance(@season)
  end
end
