require "test_helper"
require_relative "../support/domain_test_helper"

class AchievementPresentationTest < ActionDispatch::IntegrationTest
  include DomainTestHelper
  setup do
    setup_domain
    @match.update!(kickoff_at: 4.days.from_now)
    Competition.find_or_create_by!(name: "Лига чемпионов")
    AchievementCatalog.install!
  end

  test "personal catalogue uses distinct wolf art and only earned rows are highlighted" do
    earned = Achievement.find_by!(name: "Романист")
    GoldPointsService.award_achievement!(user: @user, achievement: earned, admin: @admin)
    sign_in_as(@user)
    get achievements_profile_path
    assert_response :success
    assert_select "table", count: 0
    assert_select ".achievement-list > li", count: 12
    assert_select ".achievement--earned", count: 1
    assert_select "#achievement_#{earned.id}.achievement--earned .achievement-state", text: "Получена"
    assert_select ".achievement-artwork img" do |images|
      assert_equal 12, images.map { |img| img["src"] }.uniq.size
      assert images.all? { |img| img["alt"] == "" }
    end
    sign_in_as(@other_user)
    get achievements_profile_path
    assert_select ".achievement--earned", count: 0
  end

  test "unrevealed art never exposes a secret rule even to its recipient" do
    secret = Achievement.create!(name: "Mystery", secret: true, rule_key: "three_promotions", description: "PRIVATE SECRET RULE")
    GoldPointsService.award_achievement!(user: @user, achievement: secret, admin: @admin)
    sign_in_as(@user)
    get achievements_profile_path
    assert_select "#achievement_#{secret.id}.achievement--earned img[src*='mystery']"
    assert_select "#achievement_#{secret.id} img[src*='head-hunter']", count: 0
    assert_no_match secret.description, response.body
    secret.update!(revealed: true)
    get achievements_profile_path
    assert_select "#achievement_#{secret.id} img[src*='head-hunter']"
    assert_match secret.description, response.body
  end

  test "admin list preserves counts archive status and edit links" do
    achievement = Achievement.find_by!(name: "Тестировщик")
    GoldPointsService.award_achievement!(user: @user, achievement: achievement, admin: @admin)
    achievement.update!(active: false)
    sign_in_as(@admin)
    get admin_achievements_path
    assert_response :success
    assert_select "table", count: 0
    assert_select ".achievement-list > li", count: 12
    assert_select "#achievement_#{achievement.id}.achievement--inactive" do
      assert_select ".achievement-meta", text: /Вручную.*Отключена.*Получили:\s*1/m
      assert_select "a[href=?]", edit_admin_achievement_path(achievement), text: "Изменить"
    end
    sign_in_as(@user)
    get achievements_profile_path
    assert_select "#achievement_#{achievement.id}.achievement--earned"
  end

  test "custom achievements have a neutral fallback instead of a broken image" do
    custom = Achievement.create!(name: "Custom", description: "Custom condition")
    sign_in_as(@user)
    get achievements_profile_path
    assert_select "#achievement_#{custom.id} img[src*='general']"
  end
end
