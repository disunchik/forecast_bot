require "test_helper"
require_relative "../support/domain_test_helper"

class GoldPointsServiceTest < ActiveSupport::TestCase
  include DomainTestHelper
  setup { setup_domain }

  test "manual adjustment requires integer nonzero amount and reason" do
    [ "1.5", "abc", "0" ].each do |amount|
      assert_raises(GoldPointsService::Error) { fund(amount: amount) }
    end
    assert_raises(GoldPointsService::Error) do
      GoldPointsService.manual!(user: @user, season: @season, amount: 5, note: "", admin: @admin)
    end
    assert_empty GoldPointTransaction.all
  end

  test "manual withdrawal cannot consume reserves" do
    fund(amount: 5)
    make_forecast(gold_points_stake: 5)
    assert_raises(GoldPointsService::Error) { fund(amount: -1) }
    assert_equal 5, @user.gold_points_balance(@season)
  end

  test "first ordinary and subsequent awards have correct rewards and are permanent" do
    achievement = Achievement.create!(name: "Ordinary")
    GoldPointsService.award_achievement!(user: @user, achievement: achievement, admin: @admin)
    GoldPointsService.award_achievement!(user: @other_user, achievement: achievement, admin: @admin)
    assert_equal 3, @user.gold_points_balance(@season)
    assert_equal 1, @other_user.gold_points_balance(@season)
    assert_raises(GoldPointsService::Error) { GoldPointsService.award_achievement!(user: @user, achievement: achievement, admin: @admin) }
    next_season = Season.create!(name: "Next", active: true)
    @season.update!(active: false)
    assert_equal 0, @user.gold_points_balance(next_season)
    assert @user.achievements.exists?(achievement.id)
    assert_raises(GoldPointsService::Error) { GoldPointsService.award_achievement!(user: @user, achievement: achievement, admin: @admin) }
  end

  test "secret first award reveals condition immediately and rewards five" do
    achievement = Achievement.create!(name: "Secret", secret: true)
    GoldPointsService.award_achievement!(user: @user, achievement: achievement, admin: @admin)
    assert achievement.reload.revealed?
    assert_equal 5, @user.gold_points_balance(@season)
  end

  test "manual adjustment records administrator and required reason" do
    fund(amount: 5)
    log = AuditLog.find_by!(action: "gold_points.manual")
    assert_equal @admin.id, log.admin_id
    assert_equal "Test funding", log.details["note"]
  end
end
