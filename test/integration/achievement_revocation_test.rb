require "test_helper"
require_relative "../support/domain_test_helper"

class AchievementRevocationTest < ActionDispatch::IntegrationTest
  include DomainTestHelper

  setup do
    setup_domain
    @achievement = Achievement.create!(name: "Test achievement", description: "Test condition")
    @award = GoldPointsService.award_achievement!(user: @user, achievement: @achievement, admin: @admin)
    @management = AchievementAwardManagementService.new(award: @award, admin: @admin)
  end

  test "admin sees actual recipients on detail edit and participant pages" do
    @user.update!(nickname: "Updated nickname")
    sign_in_as(@admin)
    [ admin_achievement_path(@achievement), edit_admin_achievement_path(@achievement) ].each do |path|
      get path
      assert_response :success
      assert_select "#user_achievement_#{@award.id}" do
        assert_select "a[href=?]", admin_user_path(@user), text: "Updated nickname"
        assert_select "a[href=?]", revocation_admin_achievement_award_path(@achievement, @award), text: "Отозвать"
      end
    end
    get admin_user_path(@user)
    assert_select "#user_achievement_#{@award.id} a[href=?]", revocation_admin_achievement_award_path(@achievement, @award)
    get admin_achievements_path
    assert_select "#achievement_#{@achievement.id} .achievement-meta", text: /Получили: 1/
    assert_select "#achievement_#{@achievement.id} .achievement-meta a", count: 0
    patch admin_achievement_path(@achievement), params: { achievement: { name: "" } }
    assert_response :unprocessable_entity
    assert_select "#user_achievement_#{@award.id}"
  end

  test "revoke and restore change profile recipients counts and history without affecting gold" do
    sign_in_as(@admin)
    get revocation_admin_achievement_award_path(@achievement, @award)
    assert_response :success
    assert_not @award.reload.revoked?
    assert_select "textarea[name=reason], input[name=reason]", count: 0
    post revoke_admin_achievement_award_path(@achievement, @award), params: { state_token: @management.token(action: "revoke"), confirmation: "1" }
    assert_redirected_to admin_achievement_path(@achievement)
    follow_redirect!
    assert_select "#recipients-heading", text: /Получатели 0/
    assert_select "details #user_achievement_#{@award.id}"
    get admin_user_path(@user)
    assert_select "#achievement_#{@achievement.id} form", count: 0
    assert_select "a[href=?]", restoration_admin_achievement_award_path(@achievement, @award), text: "Восстановить"
    get admin_achievements_path
    assert_select "#achievement_#{@achievement.id} .achievement-meta", text: /Получили: 0/
    assert_select "#achievement_#{@achievement.id} .achievement-meta a", count: 0
    sign_in_as(@user)
    get achievements_profile_path
    assert_select "#achievement_#{@achievement.id} .achievement-state", text: "Не получена"
    assert_select ".achievement--earned", count: 0
    sign_in_as(@admin)
    get restoration_admin_achievement_award_path(@achievement, @award)
    assert_response :success
    assert_select "textarea[name=reason], input[name=reason]", count: 0
    post restore_admin_achievement_award_path(@achievement, @award), params: { state_token: @management.token(action: "restore"), confirmation: "1" }
    assert_redirected_to admin_achievement_path(@achievement)
    assert_equal 3, @user.gold_points_balance(@season)
    assert_equal 1, GoldPointTransaction.where(achievement: @achievement).count
  end

  test "missing confirmation stale token and wrong nested achievement are rejected" do
    sign_in_as(@admin)
    [ { confirmation: nil }, { state_token: "invalid" } ].each do |bad|
      post revoke_admin_achievement_award_path(@achievement, @award), params: { state_token: @management.token(action: "revoke"), confirmation: "1" }.merge(bad)
      assert_response :unprocessable_entity
      assert_select "[role='alert']"
      assert_not @award.reload.revoked?
    end
    other = Achievement.create!(name: "Other")
    get revocation_admin_achievement_award_path(other, @award)
    assert_response :not_found
  end

  test "ordinary users cannot see recipients or invoke either mutation" do
    sign_in_as(@other_user)
    [ admin_achievement_path(@achievement), edit_admin_achievement_path(@achievement), revocation_admin_achievement_award_path(@achievement, @award), restoration_admin_achievement_award_path(@achievement, @award) ].each do |path|
      get path
      assert_redirected_to root_path
      assert_no_match @user.email_address, response.body
    end
    [ revoke_admin_achievement_award_path(@achievement, @award), restore_admin_achievement_award_path(@achievement, @award) ].each do |path|
      assert_no_difference("AuditLog.count") { post path, params: { confirmation: "1", state_token: @management.token(action: "revoke") } }
      assert_redirected_to root_path
    end
    assert_not @award.reload.revoked?
  end

  test "revoked archived awards preserve history and do not become earned in profile" do
    @management.revoke!(token: @management.token(action: "revoke"), confirmation: "1")
    sign_in_as(@admin)
    assert_no_difference("Achievement.count") { delete admin_achievement_path(@achievement) }
    assert_not @achievement.reload.active?
    assert @award.reload.revoked?
    get admin_achievement_path(@achievement)
    assert_select "details #user_achievement_#{@award.id}"
    sign_in_as(@user)
    get achievements_profile_path
    assert_select "#achievement_#{@achievement.id}", count: 0
  end
end
