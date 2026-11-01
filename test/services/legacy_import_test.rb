require "test_helper"
require_relative "../support/domain_test_helper"
require "tempfile"
require "rake"

class LegacyImportTest < ActiveSupport::TestCase
  include DomainTestHelper
  setup do
    setup_domain
    Rails.application.load_tasks unless Rake::Task.task_defined?("legacy:import_users")
  end

  def import(task_name, variable, data)
    Tempfile.create([ "legacy-test", ".json" ]) do |file|
      file.write(JSON.generate(data))
      file.flush
      before = ENV[variable]
      begin
        ENV[variable] = file.path
        task = Rake::Task[task_name]
        task.reenable
        capture_io { task.invoke }
      ensure
        before ? ENV[variable] = before : ENV.delete(variable)
      end
    end
  end

  test "legacy codewords are hashed and importing twice is safe" do
    data = { "OldFan" => "codeword" }
    import("legacy:import_users", "LEGACY_USERS", data)
    user = User.find_by!(nickname_key: "oldfan")
    assert user.legacy_account?
    assert user.needs_legacy_setup?
    assert user.authenticate("codeword")
    assert_not_equal "codeword", user.password_digest
    assert_no_difference "User.count" do
      import("legacy:import_users", "LEGACY_USERS", data)
    end
  end

  test "imported earned achievements are permanent and never award gold twice" do
    import("legacy:import_achievements", "LEGACY_ACHIEVEMENTS", [ { name: "Old Secret", description: "Condition", secret: true } ])
    data = { @user.nickname => [ "Old Secret" ] }
    assert_no_difference "GoldPointTransaction.count" do
      import("legacy:import_user_achievements", "LEGACY_USER_ACHIEVEMENTS", data)
      import("legacy:import_user_achievements", "LEGACY_USER_ACHIEVEMENTS", data)
    end
    achievement = Achievement.find_by!(name: "Old Secret")
    assert achievement.revealed?
    assert_equal 1, @user.user_achievements.where(achievement: achievement).count
    assert_raises(GoldPointsService::Error) do
      GoldPointsService.award_achievement!(user: @user, achievement: achievement, admin: @admin)
    end
  end
end
