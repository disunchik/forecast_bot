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
    error = assert_raises(GoldPointsService::Error) { fund(amount: -1) }
    assert_equal "Недостаточно ЗБ: доступно 0, для списания нужно 1. В нерассчитанных прогнозах зарезервировано 5 ЗБ.", error.message
    assert_equal 5, @user.gold_points_balance(@season)
  end

  test "withdrawal exceeding balance without forecasts reports insufficient points rather than reserves" do
    fund(amount: 3)
    assert_equal 0, @user.reserved_gold_points(@season)
    assert_no_difference [ "GoldPointTransaction.count", "AuditLog.count" ] do
      error = assert_raises(GoldPointsService::Error) { fund(amount: -4) }
      assert_equal "Недостаточно ЗБ: доступно 3, для списания нужно 4.", error.message
    end
    assert_equal 3, @user.gold_points_balance(@season)
  end

  test "withdrawal can exhaust free points while preserving a closed forecast reserve" do
    fund(amount: 5)
    make_forecast(gold_points_stake: 2)
    @match.update!(kickoff_at: 1.day.ago)
    assert_no_difference [ "GoldPointTransaction.count", "AuditLog.count" ] do
      error = assert_raises(GoldPointsService::Error) { fund(amount: -4) }
      assert_equal "Недостаточно ЗБ: доступно 3, для списания нужно 4. В нерассчитанных прогнозах зарезервировано 2 ЗБ.", error.message
    end
    fund(amount: -3)
    assert_equal 2, @user.gold_points_balance(@season)
    assert_equal 2, @user.reserved_gold_points(@season)
    assert_equal 0, @user.available_gold_points(@season)
  end

  test "withdrawal of the exact balance without reserves is allowed" do
    fund(amount: 3)
    fund(amount: -3)
    assert_equal 0, @user.gold_points_balance(@season)
  end

  test "first ordinary recipients in one round share the reward and awards are permanent" do
    achievement = Achievement.create!(name: "Ordinary")
    GoldPointsService.award_achievement!(user: @user, achievement: achievement, admin: @admin)
    GoldPointsService.award_achievement!(user: @other_user, achievement: achievement, admin: @admin)
    assert_equal 3, @user.gold_points_balance(@season)
    assert_equal 3, @other_user.gold_points_balance(@season)
    assert_raises(GoldPointsService::Error) { GoldPointsService.award_achievement!(user: @user, achievement: achievement, admin: @admin) }
    next_season = Season.create!(name: "Next", active: true)
    @season.update!(active: false)
    assert_equal 0, @user.gold_points_balance(next_season)
    assert @user.achievements.exists?(achievement.id)
    assert_raises(GoldPointsService::Error) { GoldPointsService.award_achievement!(user: @user, achievement: achievement, admin: @admin) }
  end

  test "secret first award stays hidden and rewards five" do
    achievement = Achievement.create!(name: "Secret", secret: true)
    GoldPointsService.award_achievement!(user: @user, achievement: achievement, admin: @admin)
    assert_not achievement.reload.revealed?
    assert_equal 5, @user.gold_points_balance(@season)
  end

  test "the first cohort reward is frozen even if scoring rules change within the round" do
    achievement = Achievement.create!(name: "Frozen reward", secret: true)
    GoldPointsService.award_achievement!(user: @user, achievement: achievement, admin: @admin)
    rule = ScoringRule.find_or_initialize_by(key: "achievement_secret_first")
    rule.update!(label: "First secret", value: 9)
    GoldPointsService.award_achievement!(user: @other_user, achievement: achievement, admin: @admin)
    assert_equal [ 5, 5 ], GoldPointTransaction.where(achievement: achievement).order(:amount).pluck(:amount)
    assert_equal 5, achievement.reload.first_award_points
  end

  test "manual adjustment records administrator and required reason" do
    fund(amount: 5)
    log = AuditLog.find_by!(action: "gold_points.manual")
    assert_equal @admin.id, log.admin_id
    assert_equal "Test funding", log.details["note"]
  end

  test "zero rewards still grant achievements without premature disclosure or zero ledger entries" do
    %w[achievement_normal_first achievement_secret_first achievement_subsequent].each do |key|
      rule = ScoringRule.find_or_initialize_by(key: key)
      rule.update!(label: key, value: 0)
    end
    [ false, true ].each do |secret|
      achievement = Achievement.create!(name: "Zero #{secret}", secret: secret)
      assert_no_difference "GoldPointTransaction.count" do
        GoldPointsService.award_achievement!(user: @user, achievement: achievement, admin: @admin)
        GoldPointsService.award_achievement!(user: @other_user, achievement: achievement, admin: @admin)
      end
      assert @user.achievements.exists?(achievement.id)
      assert @other_user.achievements.exists?(achievement.id)
      assert_not achievement.reload.revealed? if secret
    end
  end
end
