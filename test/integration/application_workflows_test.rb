require "test_helper"
require_relative "../support/domain_test_helper"

class ApplicationWorkflowsTest < ActionDispatch::IntegrationTest
  include DomainTestHelper
  setup { setup_domain }

  test "registration normalizes nickname and email but cannot assign admin" do
    post registrations_path, params: { user: { nickname: " Новый_Фан-1 ", email_address: " NEW@EXAMPLE.COM ", password: "password1", password_confirmation: "password1", role: "admin" } }
    assert_redirected_to root_path
    user = User.find_by!(nickname_key: "новый_фан-1")
    assert user.user?
    assert_equal "new@example.com", user.email_address
  end

  test "case insensitive nickname login works but email login does not" do
    post session_path, params: { nickname: " #{@user.nickname.upcase} ", password: "password" }
    assert_redirected_to root_path
    delete session_path
    post session_path, params: { nickname: @user.email_address, password: "password" }
    assert_redirected_to new_session_path
  end

  test "legacy codeword logs in once and setup requires new confirmed password" do
    @user.update!(legacy_account: true, must_change_password: true, email_address: nil)
    post session_path, params: { nickname: @user.nickname, password: "password" }
    assert_redirected_to edit_legacy_setup_path
    patch legacy_setup_path, params: { user: { email_address: "legacy@example.com" } }
    assert_response :unprocessable_entity
    assert @user.reload.legacy_account?
    patch legacy_setup_path, params: { user: { email_address: "legacy@example.com", password: "newpassword", password_confirmation: "newpassword" } }
    assert_redirected_to root_path
    assert_not @user.reload.needs_legacy_setup?
    assert_not @user.authenticate("password")
    assert @user.authenticate("newpassword")
  end

  test "profile protects nickname and role and revokes other sessions on password change" do
    sign_in_as(@user)
    old_nick = @user.nickname
    other_session = @user.sessions.create!
    patch profile_path, params: { user: { nickname: "Hijacked", role: "admin", email_address: "changed@example.com", password: "changedpassword", password_confirmation: "changedpassword" } }
    assert_redirected_to profile_path
    assert_equal old_nick, @user.reload.nickname
    assert @user.user?
    assert_not Session.exists?(other_session.id)
    assert_equal "changed@example.com", @user.email_address
  end

  test "guest and regular user cannot access admin endpoints or mutate data" do
    get admin_matches_path
    assert_redirected_to new_session_path
    sign_in_as(@user)
    [ admin_root_path, admin_matches_path, admin_users_path, admin_players_path, admin_competitions_path,
     admin_results_path, admin_standings_path, admin_gold_point_transactions_path, admin_seasons_path,
     admin_achievements_path, admin_audit_logs_path, admin_scoring_rules_path ].each do |path|
      get path
      assert_redirected_to root_path
    end
    assert_no_difference [ "Match.count", "Competition.count", "GoldPointTransaction.count", "UserAchievement.count" ] do
      post admin_competitions_path, params: { competition: { name: "Forbidden" } }
      patch admin_match_path(@match), params: { match: { opponent: "Forbidden" } }
      post admin_user_gold_point_transactions_path(@user), params: { amount: 999, note: "Forbidden" }
    end
  end

  test "own full forecast is linked and available before deadline while others remain hidden" do
    forecast = make_forecast
    sign_in_as(@user)
    get profile_path
    assert_select "a[href=?]", match_forecast_path(@match, forecast)
    get match_forecast_path(@match, forecast)
    assert_response :success
    sign_in_as(@other_user)
    get match_forecast_path(@match, forecast)
    assert_redirected_to root_path
    get round_path(@match)
    assert_redirected_to rounds_path
  end

  test "foreign forecast after deadline hides private gold and archive requires admin" do
    fund(amount: 71)
    forecast = make_forecast(gold_points_stake: 17)
    @match.update!(kickoff_at: 1.day.ago)
    sign_in_as(@other_user)
    get match_forecast_path(@match, forecast)
    assert_response :success
    assert_select "dt", text: "Ставка ЗБ", count: 0
    assert_no_match(/71 ЗБ|17 ЗБ/, response.body)
    @season.update!(active: false)
    get match_forecast_path(@match, forecast)
    assert_response :not_found
    sign_in_as(@admin)
    get match_forecast_path(@match, forecast)
    assert_response :success
  end

  test "direct updates after deadline cannot change forecast or last submission" do
    forecast = make_forecast
    before = forecast.attributes
    @match.update!(kickoff_at: 1.hour.from_now)
    sign_in_as(@user)
    patch match_forecast_path(@match, forecast), params: { forecast: forecast_attributes(fulltime_roma: 2, first_score: "roma") }
    assert_redirected_to root_path
    assert_equal before, forecast.reload.attributes
  end

  test "saving unchanged choice question preserves option ids and submitted answers" do
    question = @match.create_temporary_question!(text: "Question", question_type: :choice, points: 2)
    option = question.options.create!(text: "Yes")
    question.options.create!(text: "No")
    forecast = make_forecast(temporary_question_option: option)
    sign_in_as(@admin)
    patch admin_match_path(@match), params: { match: { opponent: @match.opponent }, question_enabled: "1", question_text: "Question", question_type: "choice", question_points: 2, question_options: "Yes\nNo" }
    assert_redirected_to admin_match_path(@match)
    assert_equal option.id, forecast.reload.temporary_question_option_id
    assert_equal [ "Yes", "No" ], question.options.reload.order(:id).pluck(:text)
  end

  test "postponement clears predictions and cancellation preserves history without reserves" do
    fund(amount: 10)
    forecast = make_forecast(gold_points_stake: 10)
    sign_in_as(@admin)
    patch admin_match_path(@match), params: { match: { status: "cancelled" } }
    assert Forecast.exists?(forecast.id)
    assert_equal 0, @user.reserved_gold_points(@season)
    patch admin_match_path(@match), params: { match: { status: "scheduled" } }
    assert_not Forecast.exists?(forecast.id)
    forecast = make_forecast(gold_points_stake: 10)
    patch admin_match_path(@match), params: { match: { status: "postponed" } }
    assert_not Forecast.exists?(forecast.id)
    assert_equal 10, @user.available_gold_points(@season)
  end

  test "admin manages competitions and browses archive sections" do
    sign_in_as(@admin)
    post admin_competitions_path, params: { competition: { name: "New Cup", active: "1" } }
    competition = Competition.find_by!(name: "New Cup")
    patch admin_competition_path(competition), params: { competition: { name: "Old Cup", active: "0" } }
    assert_not competition.reload.active?
    assert AuditLog.exists?(action: "competition.update", auditable: competition)
    @season.update!(active: false)
    [ admin_season_path(@season), admin_matches_path(season_id: @season.id), admin_results_path(season_id: @season.id),
     admin_standings_path(season_id: @season.id), admin_gold_point_transactions_path(season_id: @season.id) ].each do |path|
      get path
      assert_response :success
    end
  end

  test "admin preview and confirm endpoints enforce deadline" do
    sign_in_as(@admin)
    post preview_admin_match_result_path(@match)
    assert_redirected_to edit_admin_match_result_path(@match)
    post confirm_admin_match_result_path(@match)
    assert_redirected_to edit_admin_match_result_path(@match)
    assert @match.reload.scheduled?
    assert_empty ForecastScore.all
  end

  test "earned archived achievements remain visible and unrevealed conditions stay hidden" do
    achievement = Achievement.create!(name: "Permanent", description: "Known")
    GoldPointsService.award_achievement!(user: @user, achievement: achievement, admin: @admin)
    achievement.update!(active: false)
    Achievement.create!(name: "Mystery", secret: true, description: "PRIVATE CONDITION")
    sign_in_as(@user)
    get profile_path
    assert_response :success
    assert_match "Permanent", response.body
    assert_match "Mystery", response.body
    assert_no_match "PRIVATE CONDITION", response.body
  end

  test "home lists all open matches and replaces create link after submission" do
    second = make_match
    forecast = make_forecast
    sign_in_as(@user)
    get root_path
    assert_response :success
    assert_select "a[href=?]", new_match_forecast_path(@match), count: 0
    assert_select "a[href=?]", edit_match_forecast_path(@match, forecast)
    assert_select "a[href=?]", new_match_forecast_path(second)
  end
  test "all administrative mutations reject a regular user before processing parameters" do
    sign_in_as(@user)
    player = Player.create!(name: "Protected")
    achievement = Achievement.create!(name: "Protected award")
    rule = ScoringRule.first || ScoringRule.create!(key: "test_rule", label: "Test", value: 1)
    endpoints = [
      [ :post, admin_matches_path ], [ :patch, admin_match_path(@match) ], [ :delete, admin_match_path(@match) ],
      [ :patch, admin_match_result_path(@match) ], [ :post, preview_admin_match_result_path(@match) ], [ :post, confirm_admin_match_result_path(@match) ],
      [ :post, admin_players_path ], [ :patch, admin_player_path(player) ], [ :delete, admin_player_path(player) ],
      [ :patch, archive_admin_player_path(player) ], [ :patch, restore_admin_player_path(player) ],
      [ :patch, admin_user_path(@other_user) ], [ :post, admin_user_gold_point_transactions_path(@other_user) ],
      [ :post, admin_achievements_path ], [ :patch, admin_achievement_path(achievement) ], [ :delete, admin_achievement_path(achievement) ],
      [ :post, award_admin_achievement_path(achievement) ], [ :patch, admin_scoring_rule_path(rule) ],
      [ :post, admin_seasons_path ], [ :patch, activate_admin_season_path(@season) ], [ :post, rollback_admin_season_path(@season) ],
      [ :post, admin_competitions_path ], [ :patch, admin_competition_path(@competition) ], [ :post, rebuild_admin_standings_path ]
    ]
    assert_no_difference [ "AuditLog.count", "Match.count", "Forecast.count", "GoldPointTransaction.count" ] do
      endpoints.each do |method, path|
        public_send(method, path)
        assert_redirected_to root_path
      end
    end
  end

  test "cancelled match does not expose forecasts before original deadline" do
    forecast = make_forecast
    @match.update!(status: :cancelled)
    sign_in_as(@other_user)
    get match_forecast_path(@match, forecast)
    assert_redirected_to root_path
  end

  test "result form accepts unchecked void flag and multiple correct options" do
    question = @match.create_temporary_question!(text: "Q", question_type: :choice, points: 2)
    options = [ question.options.create!(text: "A"), question.options.create!(text: "B") ]
    sign_in_as(@admin)
    patch admin_match_result_path(@match), params: { match_result: forecast_attributes.except(:gold_points_stake), correct_option_ids: options.map(&:id) }
    assert_redirected_to edit_admin_match_result_path(@match)
    assert_not question.reload.voided?
    assert_equal 2, question.options.where(correct: true).count
    log = AuditLog.find_by!(action: "match_result.update")
    assert log.details.key?("before")
    assert log.details.key?("after")
  end

  test "only admin can change nickname and role without breaking forecast links" do
    forecast = make_forecast(user: @other_user)
    sign_in_as(@admin)
    patch admin_user_path(@other_user), params: { user: { nickname: "Renamed", role: "admin" } }
    assert_redirected_to admin_user_path(@other_user)
    assert @other_user.reload.admin?
    assert_equal "Renamed", forecast.reload.user.nickname
    assert AuditLog.exists?(action: "user.update", auditable: @other_user)
  end

  test "preview POST redirects to a read-only GET for Turbo" do
    @match.update!(kickoff_at: 1.day.ago)
    make_forecast
    draft_result
    sign_in_as(@admin)
    assert_no_difference [ "ForecastScore.count", "GoldPointTransaction.count" ] do
      post preview_admin_match_result_path(@match)
      assert_redirected_to preview_admin_match_result_path(@match)
      assert_response :see_other
      follow_redirect!
      assert_response :success
      assert_match "Пока ничего не начислено", response.body
    end
  end
  test "JSON requests do not expose forecasts or private gold" do
    fund(amount: 71)
    forecast = make_forecast(gold_points_stake: 17)
    @match.update!(kickoff_at: 1.day.ago)
    sign_in_as(@other_user)
    get match_forecast_path(@match, forecast), as: :json
    assert_response :not_acceptable
    assert_no_match(/gold_points_stake|gold_points_balance|password_digest/, response.body)
    get round_path(@match), as: :json
    assert_response :not_acceptable
    assert_no_match(/gold_points_stake|gold_points_balance|password_digest/, response.body)
  end
end
