require "test_helper"
require "open3"
require "tmpdir"
require "json"
require "sqlite3"

class BackupAndSeedsTest < ActiveSupport::TestCase
  test "seeds are repeatable and retain admin rule changes" do
    load Rails.root.join("db/seeds.rb")
    rule = ScoringRule.find_by!(key: "nil_nil")
    rule.update!(value: 42)
    assert_no_difference [ "Season.count", "Competition.count", "ScoringRule.count" ] do
      load Rails.root.join("db/seeds.rb")
    end
    assert_equal 42, rule.reload.value
  end

  test "online backup restores committed WAL data into new directory without overwriting" do
    Dir.mktmpdir do |root|
      source = File.join(root, "source")
      Dir.mkdir(source)
      db = SQLite3::Database.new(File.join(source, "test.sqlite3"))
      db.execute("PRAGMA journal_mode=WAL")
      db.execute("CREATE TABLE sample (value TEXT)")
      db.execute("INSERT INTO sample VALUES ('preserved')")
      output, error, status = Open3.capture3(RbConfig.ruby, Rails.root.join("bin/backup").to_s,
        "--source", source, "--destination", File.join(root, "backups"), "--environment", "test")
      assert status.success?, error
      backup = output.strip
      restored = File.join(root, "restored")
      output, error, status = Open3.capture3(RbConfig.ruby, Rails.root.join("bin/restore-backup").to_s, backup, restored)
      assert status.success?, error
      copy = SQLite3::Database.new(File.join(restored, "test.sqlite3"))
      assert_equal "preserved", copy.get_first_value("SELECT value FROM sample")
      copy.close
      _, _, status = Open3.capture3(RbConfig.ruby, Rails.root.join("bin/restore-backup").to_s, backup, restored)
      assert_not status.success?
      assert_equal "preserved", db.get_first_value("SELECT value FROM sample")
      db.close
    end
  end
end
