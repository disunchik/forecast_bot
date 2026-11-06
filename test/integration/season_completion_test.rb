require "test_helper"
require_relative "../support/domain_test_helper"

class SeasonCompletionTest < ActionDispatch::IntegrationTest
  include DomainTestHelper
  setup do
    setup_domain
    sign_in_as(@admin)
  end

  def confirm_match(match = @match)
    match.update!(kickoff_at: 1.day.ago)
    result = draft_result(match: match)
    MatchConfirmationService.new(match_result: result, admin: @admin).confirm!
  end

  def finish
    service = SeasonCompletionService.new(season: @season, admin: @admin)
    service.complete!(token: service.token, confirmation: "1")
  end

  test "season completion blocks unresolved postponed and empty seasons" do
    get admin_season_path(@season)
    assert_select "a[href=?]", completion_admin_season_path(@season), text: "Завершить сезон"
    get completion_admin_season_path(@season)
    assert_select "a[href=?]", admin_match_path(@match)
    assert_select "input[type=submit]", count: 0
    service = SeasonCompletionService.new(season: @season, admin: @admin)
    assert_raises(SeasonCompletionService::Error) { finish }
    @match.update!(status: :postponed)
    assert_raises(SeasonCompletionService::Error) { finish }
    @match.update!(status: :cancelled)
    assert_raises(SeasonCompletionService::Error) { finish }
    assert_not @season.reload.completed?
  end

  test "completion needs a fresh preview and explicit confirmation" do
    confirm_match
    service = SeasonCompletionService.new(season: @season, admin: @admin)
    token = service.token
    assert_raises(SeasonCompletionService::Error) { service.complete!(token: token, confirmation: nil) }
    achievement = Achievement.create!(name: "Season rule", rule_key: "optimist")
    assert_raises(AdminStateToken::Error) { service.complete!(token: token, confirmation: "1") }
    fresh = service.token
    make_match
    assert_raises(AdminStateToken::Error) { service.complete!(token: fresh, confirmation: "1") }
    assert_empty achievement.user_achievements
  end

  test "optimist needs five confirmed forecasts and no predicted loss across the season" do
    achievement = Achievement.create!(name: "Оптимист", rule_key: "optimist")
    5.times do |i|
      match = i.zero? ? @match : make_match
      make_forecast(match: match)
      make_forecast(match: match, user: @other_user, fulltime_opponent: i.zero? ? 1 : 0, first_score: i.zero? ? :opponent : :nobody)
      make_forecast(match: match, user: @admin) if i < 4
      confirm_match(match)
    end
    assert_empty achievement.user_achievements
    get completion_admin_season_path(@season)
    assert_response :success
    token = css_select("input[name=state_token]").first["value"]
    assert_difference "UserAchievement.count", 1 do
      post complete_admin_season_path(@season), params: { state_token: token, confirmation: "1" }
    end
    assert_redirected_to admin_season_path(@season)
    assert @season.reload.completed?
    assert @season.active?
    assert_equal @admin, @season.completed_by
    assert_equal [ @user.id ], achievement.user_achievements.pluck(:user_id)
    assert_equal 3, GoldPointTransaction.find_by!(achievement: achievement).amount
    assert AuditLog.exists?(action: "season.complete", auditable: @season, admin: @admin)
    assert_raises(SeasonCompletionService::Error) { finish }
    sign_in_as(@user)
    get standings_path
    assert_response :success
    get profile_path
    assert_response :success
    assert_select "a[href=?]", achievements_profile_path
  end

  test "first eligible optimists get the same reward together" do
    achievement = Achievement.create!(name: "Optimists", rule_key: "optimist", secret: true)
    5.times do |i|
      match = i.zero? ? @match : make_match
      [ @user, @other_user ].each { |user| make_forecast(match: match, user: user) }
      confirm_match(match)
    end
    finish
    assert_equal [ 5, 5 ], GoldPointTransaction.where(achievement: achievement).order(:amount).pluck(:amount)
    assert_not achievement.reload.revealed?
  end

  test "four confirmed forecasts and an optimistic cancelled forecast do not qualify" do
    achievement = Achievement.create!(name: "Minimum", rule_key: "optimist")
    4.times do |i|
      match = i.zero? ? @match : make_match
      make_forecast(match: match)
      confirm_match(match)
    end
    cancelled = make_match(status: :cancelled)
    make_forecast(match: cancelled)
    finish
    assert_empty achievement.user_achievements
  end

  test "rollback reopens completed season and recompletion does not duplicate awards" do
    achievement = Achievement.create!(name: "Legend", rule_key: "season_champion")
    confirm_match
    @match.standing_snapshot.entries.create!(user: @user, group_name: :top_ten, rank: 1, points: 0, last_match_points: 0)
    finish
    award_ids = achievement.user_achievements.pluck(:id)
    balance = @user.gold_points_balance(@season)
    assert_equal 1, award_ids.size
    assert_raises(ActiveRecord::RecordInvalid) { make_match }
    patch activate_admin_season_path(@season)
    assert_redirected_to admin_seasons_path
    MatchRollbackService.new(season: @season, keep_through_number: 0, admin: @admin).call!(reason: "Correction")
    assert_not @season.reload.completed?
    assert_nil @season.completed_by
    assert_equal balance, @user.gold_points_balance(@season)
    assert_equal award_ids, achievement.user_achievements.pluck(:id)
    assert AuditLog.exists?(action: "season.reopen", auditable: @season)
    MatchConfirmationService.new(match_result: @match.reload.match_result, admin: @admin).confirm!
    finish
    assert_equal award_ids, achievement.user_achievements.pluck(:id)
    assert_equal balance, @user.gold_points_balance(@season)
  end

  test "a failed completion audit rolls back the completion and its reward" do
    achievement = Achievement.create!(name: "Atomic legend", rule_key: "season_champion")
    confirm_match
    @match.standing_snapshot.entries.create!(user: @user, group_name: :top_ten, rank: 1, points: 0, last_match_points: 0)
    connection = ActiveRecord::Base.connection
    connection.execute("CREATE TEMP TRIGGER reject_completion BEFORE INSERT ON audit_logs WHEN NEW.action = 'season.complete' BEGIN SELECT RAISE(ABORT, 'test rejection'); END")
    begin
      assert_raises(ActiveRecord::StatementInvalid) { finish }
    ensure
      connection.execute("DROP TRIGGER IF EXISTS reject_completion")
    end
    assert_not @season.reload.completed?
    assert_empty achievement.user_achievements
    assert_empty GoldPointTransaction.where(achievement: achievement)
  end

  test "regular participants cannot preview or finish a season" do
    sign_in_as(@user)
    get completion_admin_season_path(@season)
    assert_redirected_to root_path
    assert_no_difference "AuditLog.count" do
      post complete_admin_season_path(@season), params: { confirmation: "1" }
    end
    assert_redirected_to root_path
    assert_not @season.reload.completed?
  end

  test "secret conditions stay out of the HTML until the next round opens" do
    confirm_match
    achievement = Achievement.create!(name: "Hidden", secret: true, description: "PRIVATE ACHIEVEMENT CONDITION")
    GoldPointsService.award_achievement!(user: @user, achievement: achievement, admin: @admin)
    sign_in_as(@user)
    get achievements_profile_path
    assert_no_match achievement.description, response.body
    sign_in_as(@other_user)
    get achievements_profile_path
    assert_no_match achievement.description, response.body
    later = make_match(kickoff: 4.days.from_now.change(usec: 0))
    travel_to later.forecast_opens_at do
      get achievements_profile_path
      assert_match achievement.description, response.body
    end
  end

  test "admin can configure an existing achievement for automatic checks" do
    achievement = Achievement.create!(name: "Existing")
    get edit_admin_achievement_path(achievement)
    assert_select "select[name='achievement[rule_key]']"
    patch admin_achievement_path(achievement), params: { achievement: { rule_key: "europe_exact", competition_ids: [ "", @competition.id.to_s ] } }
    assert_redirected_to admin_achievements_path
    assert_equal "europe_exact", achievement.reload.rule_key
    assert_equal [ @competition.id ], achievement.competition_ids
    assert_equal 0, UserAchievement.count
    assert AuditLog.exists?(action: "achievement.update", auditable: achievement, admin: @admin)
  end
end
