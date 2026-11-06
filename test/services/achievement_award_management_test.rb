require "test_helper"
require_relative "../support/domain_test_helper"

class AchievementAwardManagementTest < ActiveSupport::TestCase
  include DomainTestHelper

  setup do
    setup_domain
    @achievement = Achievement.create!(name: "Managed award", rule_key: "top_leader")
    @award = GoldPointsService.award_achievement!(user: @user, achievement: @achievement, admin: @admin)
    @management = AchievementAwardManagementService.new(award: @award, admin: @admin)
  end

  def revoke(**options)
    @management.revoke!(**{ token: @management.token(action: "revoke"), confirmation: "1" }.merge(options))
  end

  test "revoke preserves award history funds reservations and first cohort" do
    original = @award.attributes
    cohort = @achievement.reload.attributes
    make_forecast(gold_points_stake: 3)
    assert_no_difference [ "UserAchievement.count", "GoldPointTransaction.count" ] do
      assert_difference("AuditLog.where(action: 'achievement.revoke').count", 1) { revoke }
    end
    assert @award.reload.revoked?
    assert_equal @admin, @award.revoked_by
    assert_nil @award.revocation_reason
    assert_equal original["awarded_at"], @award.awarded_at
    assert_equal 3, @user.gold_points_balance(@season)
    assert_equal 3, @user.reserved_gold_points(@season)
    assert_not @user.achievements.exists?(@achievement.id)
    assert_not @achievement.users.exists?(@user.id)
    assert_equal cohort, @achievement.reload.attributes
    log = AuditLog.find_by!(action: "achievement.revoke")
    assert_equal @admin, log.admin
    assert_equal @user.id, log.details["user_id"]
    assert_equal @award.id, log.details["award_id"]
    assert_equal "preserved", log.details["gold_points"]
  end

  test "confirmation admin and a current action bound token are required" do
    [ { confirmation: nil }, { token: "invalid" }, { token: @management.token(action: "restore") } ].each do |options|
      assert_no_difference("AuditLog.count") do
        assert_raises(AchievementAwardManagementService::Error, AdminStateToken::Error) { revoke(**options) }
      end
      assert_not @award.reload.revoked?
    end
    invalid = AchievementAwardManagementService.new(award: @award, admin: @user)
    assert_raises(AchievementAwardManagementService::Error) do
      invalid.revoke!(token: invalid.token(action: "revoke"), confirmation: "1")
    end
  end

  test "duplicate requests and old revoke forms cannot affect a restored award" do
    old_token = @management.token(action: "revoke")
    revoke(token: old_token)
    assert_no_difference("AuditLog.count") do
      assert_raises(AdminStateToken::Error) { revoke(token: old_token) }
    end
    @management.restore!(token: @management.token(action: "restore"), confirmation: "1")
    assert_no_difference("AuditLog.count") do
      assert_raises(AdminStateToken::Error) { revoke(token: old_token) }
    end
    assert_not @award.reload.revoked?
  end

  test "restoration works without active season and never pays again" do
    original_time = @award.awarded_at
    revoke
    @season.update!(active: false)
    @achievement.update!(active: false)
    assert_no_difference [ "UserAchievement.count", "GoldPointTransaction.count" ] do
      @management.restore!(token: @management.token(action: "restore"), confirmation: "1")
    end
    assert_nil @award.reload.revoked_at
    assert_nil @award.revoked_by_id
    assert_nil @award.revocation_reason
    assert_equal original_time, @award.awarded_at
    assert @user.achievements.exists?(@achievement.id)
    assert_equal 3, @user.gold_points_balance(@season)
    assert_equal 1, AuditLog.where(action: "achievement.restore").count
  end

  test "automatic and manual granting cannot undo revocation or mint another first reward" do
    cohort = @achievement.reload.slice(:first_award_season_id, :first_award_round, :first_award_points)
    revoke
    assert_no_difference("GoldPointTransaction.count") do
      assert_empty GoldPointsService.award_achievements!(users: [ @user ], achievement: @achievement, admin: @admin, season: @season)
      assert_raises(GoldPointsService::Error) { GoldPointsService.award_achievement!(user: @user, achievement: @achievement, admin: @admin) }
    end
    assert @award.reload.revoked?
    GoldPointsService.award_achievements!(users: [ @other_user ], achievement: @achievement, admin: @admin, season: @season, round: 1)
    assert_equal 1, @other_user.gold_points_balance(@season)
    assert_equal cohort, @achievement.reload.slice(:first_award_season_id, :first_award_round, :first_award_points)
  end

  test "audit failure rolls back revocation" do
    failure = -> { raise "audit unavailable" }
    AuditLog.set_callback(:create, :before, failure)
    assert_raises(RuntimeError) { revoke }
    assert_not @award.reload.revoked?
    assert_equal 3, @user.gold_points_balance(@season)
  ensure
    AuditLog.skip_callback(:create, :before, failure)
  end
end
