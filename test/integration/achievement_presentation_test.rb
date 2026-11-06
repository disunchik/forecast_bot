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

  test "earned achievements lead by award time with a deterministic tie and owned archives" do
    older = Achievement.find_by!(name: "Тестировщик")
    latest = Achievement.find_by!(name: "Царь горы")
    tied = Achievement.find_by!(name: "Романист")
    time = 1.day.ago
    @user.user_achievements.create!(achievement: older, awarded_at: time - 1.hour)
    @user.user_achievements.create!(achievement: latest, awarded_at: time)
    @user.user_achievements.create!(achievement: tied, awarded_at: time)
    older.update!(active: false)
    @other_user.user_achievements.create!(achievement: Achievement.find_by!(name: "Дебютант"), awarded_at: Time.current)
    hidden_archive = Achievement.create!(name: "Не моя архивная", active: false)
    sign_in_as(@user)
    get achievements_profile_path
    assert_response :success
    rows = css_select(".achievement-list > li").map { |row| row["id"] }
    assert_equal [ tied, latest, older ].map { |achievement| "achievement_#{achievement.id}" }, rows.first(3)
    expected_remaining = Achievement.active.where.not(id: [ tied.id, latest.id, older.id ]).sort_by(&:name)
    assert_equal expected_remaining.map { |achievement| "achievement_#{achievement.id}" }, rows.drop(3)
    assert_select "#achievement_#{hidden_archive.id}", count: 0
    assert_select ".achievement--earned", count: 3
  end

  test "admin award sections show conditions and preserve automatic fallback and manual grants" do
    automatic = Achievement.find_by!(name: "Романист")
    manual = Achievement.find_by!(name: "Тестировщик")
    earned = Achievement.find_by!(name: "Царь горы")
    archived = Achievement.create!(name: "Отключённая", active: false)
    secret = Achievement.create!(name: "Секрет", rule_key: "three_promotions", secret: true, description: "ADMIN ONLY CONDITION")
    GoldPointsService.award_achievement!(user: @user, achievement: earned, admin: @admin)
    sign_in_as(@admin)
    get admin_user_path(@user)
    assert_response :success
    assert_select "section[aria-labelledby='automatic-achievements-heading']" do
      assert_select "h2", text: "Выдать автоматические"
      assert_select "#achievement_#{automatic.id} .achievement-description", text: automatic.description
      assert_select "#achievement_#{manual.id}", count: 0
      assert_select "#achievement_#{secret.id} .achievement-description", text: secret.description
      assert_select "#achievement_#{secret.id} img[src*='head-hunter']"
    end
    assert_select "section[aria-labelledby='manual-achievements-heading']" do
      assert_select "h2", text: "Выдать ручные"
      assert_select "#achievement_#{manual.id} .achievement-description", text: manual.description
      assert_select ".achievement", count: 1
    end
    assert_select "#achievement_#{earned.id}", count: 0
    assert_select "#achievement_#{archived.id}", count: 0
    [ automatic, manual ].each do |achievement|
      assert_difference("@user.user_achievements.count", 1) do
        post award_admin_achievement_path(achievement), params: { user_id: @user.id }
      end
      assert_redirected_to admin_user_path(@user)
      follow_redirect!
      assert_select "#achievement_#{achievement.id}", count: 0
      assert_no_difference("@user.user_achievements.count") do
        post award_admin_achievement_path(achievement), params: { user_id: @user.id }
      end
    end
    sign_in_as(@user)
    assert_no_difference("@other_user.user_achievements.count") do
      post award_admin_achievement_path(automatic), params: { user_id: @other_user.id }
    end
    assert_redirected_to root_path
    get achievements_profile_path
    assert_no_match secret.description, response.body
  end

  test "admin award groups have independent empty states" do
    Achievement.active.each { |achievement| @user.user_achievements.create!(achievement: achievement, awarded_at: Time.current) }
    sign_in_as(@admin)
    get admin_user_path(@user)
    assert_select "section[aria-labelledby='automatic-achievements-heading'] .empty", text: "Доступных автоматических ачивок для выдачи нет."
    assert_select "section[aria-labelledby='manual-achievements-heading'] .empty", text: "Доступных ручных ачивок для выдачи нет."
    assert_select ".achievement-actions form", count: 0
  end
end
