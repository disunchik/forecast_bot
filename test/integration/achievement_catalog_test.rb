require "test_helper"
require_relative "../support/domain_test_helper"

class AchievementCatalogTest < ActionDispatch::IntegrationTest
  include DomainTestHelper
  setup do
    setup_domain
    @champions = Competition.find_or_create_by!(name: "Лига чемпионов")
    @europa = Competition.find_or_create_by!(name: "Лига Европы")
  end

  test "catalogue creates all twelve requested definitions with eleven automatic rules" do
    created = nil
    assert_no_difference [ "UserAchievement.count", "GoldPointTransaction.count" ] do
      created = AchievementCatalog.install!(admin: @admin)
    end
    assert_equal 12, created.size
    assert_equal AchievementCatalog::DEFINITIONS.map { |definition| definition.fetch(:name) }.sort, created.map(&:name).sort
    assert created.all?(&:active?)
    assert created.none?(&:secret?)
    assert created.all? { |achievement| achievement.description.present? }
    assert_equal 11, created.count { |achievement| achievement.rule_key.present? }
    assert_nil Achievement.find_by!(name: "Тестировщик").rule_key
    cup = Achievement.find_by!(name: "Главный по чашечкам")
    assert_equal [ @champions.id, @europa.id ].sort, cup.competition_ids.sort
    assert_not cup.competition_ids.include?(@competition.id)
    assert_equal 12, AuditLog.where(action: "achievement.create", admin: @admin).count
    assert_not Achievement.exists?(name: "Ачивмент Хантер")
  end

  test "reinstall never resets administrator settings or existing rewards" do
    achievement = Achievement.create!(name: "Романист", description: "Administrator condition", secret: true)
    GoldPointsService.award_achievement!(user: @user, achievement: achievement, admin: @admin)
    achievement.update!(active: false)
    before = achievement.attributes
    AchievementCatalog.install!
    assert_equal before, achievement.reload.attributes
    assert_equal 1, achievement.user_achievements.count
    assert_no_difference [ "Achievement.count", "AuditLog.count", "UserAchievement.count", "GoldPointTransaction.count" ] do
      assert_empty AchievementCatalog.install!
    end
    assert_equal before, achievement.reload.attributes
  end

  test "a failed definition rolls back the entire catalogue without partial records" do
    assert_no_difference [ "Achievement.count", "AuditLog.count", "GoldPointTransaction.count" ] do
      assert_raises(ActiveRecord::RecordInvalid) { AchievementCatalog.install!(european_competition_ids: [ -1 ]) }
    end
  end

  test "catalogue is visible in user profile and administrator lists" do
    AchievementCatalog.install!
    sign_in_as(@user)
    get achievements_profile_path
    assert_response :success
    assert_select "h1", text: /0\/12/
    AchievementCatalog::DEFINITIONS.each do |definition|
      assert_select ".achievement-heading h2", text: definition.fetch(:name)
    end
    sign_in_as(@admin)
    get admin_achievements_path
    assert_response :success
    assert_select "tbody tr", count: 12
    get admin_user_path(@user)
    tester = Achievement.find_by!(name: "Тестировщик")
    assert_select "form[action=?]", award_admin_achievement_path(tester) do
      assert_select "input[name=user_id][value=?]", @user.id.to_s
    end
  end

  test "tester stays manual while the seeded derby achievement awards automatically" do
    AchievementCatalog.install!
    @match.update!(kickoff_at: 1.day.ago, opponent: "Лацио")
    make_forecast
    MatchConfirmationService.new(match_result: draft_result, admin: @admin).confirm!
    assert @user.achievements.exists?(name: "Романист")
    tester = Achievement.find_by!(name: "Тестировщик")
    assert_empty tester.user_achievements
    sign_in_as(@admin)
    post award_admin_achievement_path(tester), params: { user_id: @user.id }
    assert_redirected_to admin_user_path(@user)
    assert tester.user_achievements.exists?(user: @user)
    assert_equal 3, GoldPointTransaction.find_by!(achievement: tester, user: @user).amount
  end
end
