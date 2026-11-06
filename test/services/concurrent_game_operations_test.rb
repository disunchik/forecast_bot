require "test_helper"
require_relative "../support/domain_test_helper"

class ConcurrentGameOperationsTest < ActiveSupport::TestCase
  include DomainTestHelper
  self.use_transactional_tests = false

  setup { setup_domain }
  teardown do
    if @season&.persisted?
      GoldPointTransaction.where(season: @season).delete_all
      @achievement&.destroy!
      @achievement = nil
      @season.matches.destroy_all
      @season.destroy!
    end
    AuditLog.where(admin: @admin).delete_all
    if @second_admin
      AuditLog.where(admin: @second_admin).delete_all
      @second_admin.destroy!
    end
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

  test "parallel first secret awards in one round both receive the first reward" do
    @achievement = Achievement.create!(name: "Race #{SecureRandom.hex(4)}", secret: true)
    users = [ @user, @other_user ]
    results = race(*users.map do |user|
      -> { GoldPointsService.award_achievement!(user: User.find(user.id), achievement: Achievement.find(@achievement.id), admin: @admin, season: @season); true }
    end)
    assert_equal [ true, true ], results, results.inspect
    assert_equal [ 5, 5 ], GoldPointTransaction.where(achievement: @achievement).order(:amount).pluck(:amount)
  end

  test "parallel achievement revocations keep one audit entry and never regrant automatically" do
    @achievement = Achievement.create!(name: "Revoke race #{SecureRandom.hex(4)}")
    award = GoldPointsService.award_achievement!(user: @user, achievement: @achievement, admin: @admin)
    token = AchievementAwardManagementService.new(award: award, admin: @admin).token(action: "revoke")
    operation = -> do
      management = AchievementAwardManagementService.new(award: UserAchievement.find(award.id), admin: @admin)
      management.revoke!(token: token, reason: "Race", confirmation: "1")
      true
    end
    results = race(operation, operation)
    assert_equal 1, results.count(true), results.inspect
    assert_equal 1, results.count { |result| result.is_a?(AdminStateToken::Error) }, results.inspect
    assert_equal 1, AuditLog.where(action: "achievement.revoke", auditable: @achievement).count
    assert award.reload.revoked?
    assert_equal 3, @user.gold_points_balance(@season)
    assert_empty GoldPointsService.award_achievements!(users: [ @user ], achievement: @achievement, admin: @admin, season: @season)
  end

  test "parallel season completion grants seasonal rewards once" do
    @achievement = Achievement.create!(name: "Season race #{SecureRandom.hex(4)}", rule_key: "optimist")
    5.times do |index|
      match = index.zero? ? @match : make_match
      match.update!(kickoff_at: 1.day.ago)
      make_forecast(match: match)
      MatchConfirmationService.new(match_result: draft_result(match: match), admin: @admin).confirm!
    end
    token = SeasonCompletionService.new(season: @season, admin: @admin).token
    operation = -> do
      service = SeasonCompletionService.new(season: Season.find(@season.id), admin: @admin)
      service.complete!(token: token, confirmation: "1")
      true
    rescue SeasonCompletionService::Error
      false
    end
    results = race(operation, operation)
    assert_equal [ false, true ], results.sort_by(&:to_s), results.inspect
    assert @season.reload.completed?
    assert_equal 1, UserAchievement.where(achievement: @achievement).count
    assert_equal 3, GoldPointTransaction.where(achievement: @achievement).sum(:amount)
    assert_equal 1, AuditLog.where(action: "season.complete", auditable: @season).count
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

  def signed_admin_session(user)
    session = ActionDispatch::Integration::Session.new(Rails.application)
    session.post "/session", params: { nickname: user.nickname, password: "password" }
    session
  end

  test "parallel self demotions cannot remove the last administrator" do
    @second_admin = User.create!(nickname: "Second#{SecureRandom.hex(5)}", email_address: "#{SecureRandom.hex(5)}@example.com",
                                 password: "password", password_confirmation: "password", role: :admin)
    sessions = [ @admin, @second_admin ].map { |user| [ user, signed_admin_session(user) ] }
    results = race(*sessions.map do |user, session|
      -> { session.patch "/admin/users/#{user.id}", params: { user: { role: "user" } }; session.response.status }
    end)
    assert_equal [ 302, 422 ], results.sort, results.inspect
    assert_equal 1, User.admin.count
  end

  test "parallel result page visits create one draft" do
    @match.update!(kickoff_at: 1.day.ago)
    sessions = 2.times.map { signed_admin_session(@admin) }
    results = race(*sessions.map do |session|
      -> { session.get "/admin/matches/#{@match.id}/result/edit"; session.response.status }
    end)
    assert_equal [ 200, 200 ], results, results.inspect
    assert_equal 1, MatchResult.where(match: @match).count
  end
end
