require "test_helper"
require_relative "../support/domain_test_helper"

class AdminLifecycleTest < ActionDispatch::IntegrationTest
  include DomainTestHelper
  setup do
    setup_domain
    sign_in_as(@admin)
  end

  def result_token(match = @match)
    get edit_admin_match_result_path(match)
    assert_response :success
    css_select("input[name=state_token]").first["value"]
  end

  def confirm_token(match = @match)
    get preview_admin_match_result_path(match)
    assert_response :success
    css_select("input[name=state_token]").first["value"]
  end

  test "exact deadline freezes conditions and question even with a valid token" do
    question = @match.create_temporary_question!(text: "Q", question_type: :choice, points: 2)
    option = question.options.create!(text: "A")
    forecast = make_forecast(temporary_question_option: option)
    travel_to @match.forecast_closes_at, with_usec: true do
      token = MatchAdminPolicy.edit_token(@match)
      patch admin_match_path(@match), params: { state_token: token, match: { kickoff_at: 10.days.from_now, opponent: "Changed" },
                                             question_enabled: "1", question_text: "Q!", question_type: "choice", question_points: 2, question_options: "A" }
      assert_redirected_to admin_match_path(@match)
      assert_equal "Inter", @match.reload.opponent
      assert_equal "Q", question.reload.text
      assert Forecast.exists?(forecast.id)
      assert_not @match.forecast_open?
    end
  end

  test "result editing after deadline is allowed and audit keeps correct answer changes" do
    @match.update!(kickoff_at: 1.day.ago)
    question = @match.create_temporary_question!(text: "Q", question_type: :choice, points: 2)
    a, b = [ question.options.create!(text: "A"), question.options.create!(text: "B") ]
    [ a, b ].each do |option|
      patch admin_match_result_path(@match), params: { state_token: result_token, match_result: forecast_attributes.except(:gold_points_stake), correct_option_ids: [ option.id ] }
      assert_redirected_to edit_admin_match_result_path(@match)
    end
    log = AuditLog.where(action: "match_result.update").order(:id).last
    assert_equal a.id, log.details.dig("before", "question", "options").find { |o| o["correct"] }.fetch("id")
    assert_equal b.id, log.details.dig("after", "question", "options").find { |o| o["correct"] }.fetch("id")
    assert_not @match.match_result.confirmed?
  end

  test "no result or right answer can be set before deadline" do
    token = result_token
    patch admin_match_result_path(@match), params: { state_token: token, match_result: forecast_attributes(fulltime_opponent: 1).except(:gold_points_stake) }
    assert_redirected_to edit_admin_match_result_path(@match)
    assert_equal 0, @match.reload.match_result.fulltime_opponent
  end

  test "stale match and result forms cannot overwrite a newer save" do
    token = MatchAdminPolicy.edit_token(@match)
    patch admin_match_path(@match), params: { state_token: token, match: { opponent: "Milan" } }
    assert_equal "Milan", @match.reload.opponent
    patch admin_match_path(@match), params: { state_token: token, match: { opponent: "Stale" } }
    assert_equal "Milan", @match.reload.opponent
    @match.update!(kickoff_at: 1.day.ago)
    token = result_token
    patch admin_match_result_path(@match), params: { state_token: token, match_result: forecast_attributes(fulltime_opponent: 1).except(:gold_points_stake) }
    patch admin_match_result_path(@match), params: { state_token: token, match_result: forecast_attributes(fulltime_opponent: 2).except(:gold_points_stake) }
    assert_equal 1, @match.reload.match_result.fulltime_opponent
  end

  test "preview confirmation is invalidated by changed scoring rules" do
    @match.update!(kickoff_at: 1.day.ago)
    make_forecast
    draft_result
    token = confirm_token
    rule = ScoringRule.find_or_initialize_by(key: "nil_nil")
    rule.update!(label: "0:0", value: 9)
    post confirm_admin_match_result_path(@match), params: { state_token: token }
    assert_not @match.reload.match_result.confirmed?
    assert_empty ForecastScore.all
    post confirm_admin_match_result_path(@match), params: { state_token: confirm_token }
    assert @match.reload.match_result.confirmed?
  end

  test "reset requires preview and preserves original forecasts and removed options in audit" do
    q = @match.create_temporary_question!(text: "Old", question_type: :choice, points: 2)
    option = q.options.create!(text: "Old choice")
    forecast = make_forecast(temporary_question_option: option)
    attrs = { state_token: MatchAdminPolicy.edit_token(@match), match: { opponent: @match.opponent },
              question_enabled: "1", question_text: "New", question_type: "choice", question_points: 2, question_options: "New choice" }
    patch admin_match_path(@match), params: attrs
    assert_response :unprocessable_entity
    assert_select "h2", "Сейчас"
    assert_select "h2", "После изменения"
    assert_select "li", "Old choice"
    assert_select "li", "New choice"
    assert Forecast.exists?(forecast.id)
    assert_equal "Old choice", option.reload.text
    patch admin_match_path(@match), params: attrs.merge(confirm_reset: "1", reason: "New conditions")
    assert_redirected_to admin_match_path(@match)
    assert_not Forecast.exists?(forecast.id)
    log = AuditLog.find_by!(action: "match.forecasts_reset")
    assert_equal option.id, log.details["forecasts"].first["temporary_question_option_id"]
    assert_equal "Old choice", log.details["question"]["options"].first["text"]
    assert_equal "New conditions", log.details["reason"]
  end

  test "history prevents changing season and number even after rollback" do
    @match.update!(kickoff_at: 1.day.ago)
    make_forecast
    MatchConfirmationService.new(match_result: draft_result, admin: @admin).confirm!
    MatchRollbackService.new(season: @season, keep_through_number: 0, admin: @admin).call!
    another = Season.create!(name: "Another")
    @match.assign_attributes(season: another, forecast_number: 9)
    assert_not @match.valid?
    assert_equal @season.id, Match.find(@match.id).season_id
    assert_equal 3, @user.gold_points_balance(@season)
    assert_equal 0, @user.gold_points_balance(another)
  end

  test "delete unconfirmed closed match frees reserves and keeps audit copy" do
    fund(amount: 5)
    forecast = make_forecast(gold_points_stake: 5)
    @match.update!(kickoff_at: 1.day.ago)
    get deletion_admin_match_path(@match)
    token = css_select("input[name=state_token]").first["value"]
    delete admin_match_path(@match), params: { state_token: token, confirmation: @match.forecast_number, reason: "Cancelled game" }
    assert_redirected_to admin_matches_path
    assert_not Match.exists?(@match.id)
    assert_not Forecast.exists?(forecast.id)
    assert_equal 5, @user.available_gold_points(@season)
    log = AuditLog.find_by!(action: "match.destroy")
    assert_equal forecast.id, log.details["match"]["forecasts"].first["id"]
  end

  test "confirmed deletion cascades rollback without losing awarded gold or ledger" do
    fund(amount: 10)
    @match.update!(kickoff_at: 2.days.ago)
    make_forecast(gold_points_stake: 2)
    MatchConfirmationService.new(match_result: draft_result, admin: @admin).confirm!
    later = make_match(kickoff: 1.day.ago)
    forecast = make_forecast(match: later, gold_points_stake: 2)
    result = draft_result(match: later)
    MatchConfirmationService.new(match_result: result, admin: @admin).confirm!
    original_ids = GoldPointTransaction.pluck(:id)
    service = MatchDestructionService.new(match: @match, admin: @admin)
    assert_equal [ 1, 2 ], service.affected_matches.pluck(:forecast_number)
    service.call!(token: service.token, reason: "Invalid match", confirmation: "1")
    assert_not Match.exists?(@match.id)
    assert result.reload.draft?
    assert Forecast.exists?(forecast.id)
    assert_empty @season.standing_snapshots
    assert_equal 16, @user.gold_points_balance(@season)
    assert_equal 2, @user.reserved_gold_points(@season)
    assert_equal original_ids.sort, GoldPointTransaction.where(id: original_ids).pluck(:id).sort
    MatchConfirmationService.new(match_result: result, admin: @admin).confirm!
    assert_equal 14, @user.gold_points_balance(@season)
    assert_equal 6, GoldPointTransaction.placement.sum(:amount)
  end

  test "deletion rejects stale preview and missing reason or confirmation" do
    service = MatchDestructionService.new(match: @match, admin: @admin)
    token = service.token
    assert_raises(MatchDestructionService::Error) { service.call!(token: token, reason: "", confirmation: "1") }
    fund(amount: 1)
    assert_raises(AdminStateToken::Error) { service.call!(token: token, reason: "Delete", confirmation: "1") }
    assert Match.exists?(@match.id)
  end

  test "failed delete rolls back all spending reversals and results" do
    fund(amount: 5)
    @match.update!(kickoff_at: 1.day.ago)
    forecast = make_forecast(gold_points_stake: 2)
    result = draft_result
    MatchConfirmationService.new(match_result: result, admin: @admin).confirm!
    balance = @user.gold_points_balance(@season)
    service = MatchDestructionService.new(match: @match, admin: @admin)
    token = service.token
    connection = ActiveRecord::Base.connection
    connection.execute("CREATE TEMP TRIGGER reject_audit BEFORE INSERT ON audit_logs WHEN NEW.action = 'match.destroy' BEGIN SELECT RAISE(ABORT, 'test audit rejection'); END")
    begin
      assert_raises(ActiveRecord::StatementInvalid) { service.call!(token: token, reason: "Delete", confirmation: "1") }
    ensure
      connection.execute("DROP TRIGGER IF EXISTS reject_audit")
    end
    assert result.reload.confirmed?
    assert forecast.reload.forecast_score
    assert_equal balance, @user.gold_points_balance(@season)
    assert_empty GoldPointTransaction.stake_refund
  end

  test "rollback needs preview confirmation and cannot refund twice" do
    fund(amount: 5)
    @match.update!(kickoff_at: 1.day.ago)
    make_forecast(gold_points_stake: 2)
    result = draft_result
    MatchConfirmationService.new(match_result: result, admin: @admin).confirm!
    get rollback_preview_admin_season_path(@season), params: { before_first: "1" }
    assert_response :success
    assert_select "p", /Будут отменены все подтверждённые расчёты сезона/
    assert_select "input[name=before_first][value='1']"
    token = css_select("input[name=state_token]").first["value"]
    post rollback_admin_season_path(@season), params: { keep_through_number: 0 }
    assert result.reload.confirmed?
    post rollback_admin_season_path(@season), params: { keep_through_number: 0, state_token: token, confirmation: "1", reason: "Correction" }
    assert result.reload.draft?
    post rollback_admin_season_path(@season), params: { keep_through_number: 0, state_token: token, confirmation: "1", reason: "Retry" }
    assert_equal 2, GoldPointTransaction.stake_refund.sum(:amount)
    assert_equal(-2, GoldPointTransaction.stake.sum(:amount))
    assert_equal 8, @user.gold_points_balance(@season)
    assert_equal 2, @user.reserved_gold_points(@season)
  end

  test "away scores use home away display and preserve team meaning" do
    @match.update!(venue: :away)
    forecast = make_forecast(fulltime_roma: 1)
    sign_in_as(@user)
    get match_forecast_path(@match, forecast)
    assert_match "Inter — Рома", response.body
    assert_select "dd", text: "0:1"
    assert_equal "roma", forecast.reload.first_score
    get edit_match_forecast_path(@match, forecast)
    fields = css_select(".score-fields input").map { |field| field["name"] }
    assert_equal %w[forecast[halftime_opponent] forecast[halftime_roma] forecast[fulltime_opponent] forecast[fulltime_roma]], fields
  end

  test "settings cannot rewrite closed match rules before the first calculation" do
    @match.update!(kickoff_at: 1.day.ago)
    make_forecast
    rule = ScoringRule.find_or_initialize_by(key: "nil_nil")
    rule.update!(label: "0:0", value: 2)
    patch admin_scoring_rule_path(rule), params: { scoring_rule: { value: 100 } }
    assert_redirected_to admin_scoring_rules_path
    assert_equal 2, rule.reload.value
    MatchConfirmationService.new(match_result: draft_result, admin: @admin).confirm!
    patch admin_scoring_rule_path(rule), params: { scoring_rule: { value: 100 } }
    assert_equal 100, rule.reload.value
    assert_equal 2, @match.reload.match_result.scoring_snapshot["nil_nil"]
  end

  test "season activation cannot hide uncalculated forecasts from the current season" do
    make_forecast
    next_season = Season.create!(name: "Blocked next")
    patch activate_admin_season_path(next_season)
    assert_redirected_to admin_seasons_path
    assert @season.reload.active?
    assert_not next_season.reload.active?
    @match.update!(kickoff_at: 1.day.ago)
    MatchConfirmationService.new(match_result: draft_result, admin: @admin).confirm!
    patch activate_admin_season_path(next_season)
    assert next_season.reload.active?
    assert_not @season.reload.active?
  end
end
