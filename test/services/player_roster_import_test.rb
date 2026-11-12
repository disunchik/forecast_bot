require "test_helper"
require_relative "../support/domain_test_helper"
require_relative "../support/roster_test_helper"

class PlayerRosterImportTest < ActiveSupport::TestCase
  include DomainTestHelper
  include RosterTestHelper
  setup { setup_domain }

  def preview(snapshot = roster_snapshot)
    PlayerRosterImport.preview(snapshot: snapshot, admin: @admin)
  end

  test "saved preview is read only and defaults new Russian names to create" do
    assert_no_difference [ "Player.count", "AuditLog.count" ] do
      payload, token = preview
      assert_equal 25, payload.fetch("rows").size
      assert_equal "saved", payload.dig("snapshot", "source")
      assert_equal payload, PlayerRosterImport.read(token: token, admin: @admin)
      assert payload.fetch("rows").all? { |row| row.fetch("name").match?(/[А-Яа-я]/) && PlayerRosterImport.default_action(row) == "create" }
    end
  end

  test "import preserves linked IDs names inactive state forecasts and mention history" do
    player = Player.create!(name: "  ДЭВИС ВАСКЕС  ", active: false)
    missing = Player.create!(name: "Ушедший футболист")
    forecast = make_forecast
    forecast.forecast_scorers.create!(player: player)
    original = player.attributes.except("roma_profile_key", "updated_at")
    payload, token = preview
    row = payload.fetch("rows").find { |item| item["key"] == "devis-vasquez" }
    assert_equal "inactive", row.fetch("status")
    assert_difference("Player.count", 24) do
      assert_no_difference [ "Forecast.count", "ForecastScorer.count", "GoldPointTransaction.count" ] do
        counts = PlayerRosterImport.apply!(token: token, choices: roster_choices(payload), admin: @admin)
        assert_equal({ created: 24, linked: 1, skipped: 0 }, counts)
      end
    end
    assert_equal original, player.reload.attributes.except("roma_profile_key", "updated_at")
    assert_equal "devis-vasquez", player.roma_profile_key
    assert missing.reload.active?
    assert_equal player.id, forecast.forecast_scorers.sole.player_id
    assert_equal 1, AuditLog.where(action: "players.roster_import").count
    assert_equal @admin.id, AuditLog.find_by!(action: "player.roster_link").admin_id
    assert_raises(PlayerRosterImport::StalePreview) { PlayerRosterImport.apply!(token: token, choices: roster_choices(payload), admin: @admin) }
    fresh, fresh_token = preview
    assert_no_difference("Player.count") { PlayerRosterImport.apply!(token: fresh_token, choices: roster_choices(fresh), admin: @admin) }
  end

  test "profile key wins over changed spelling and never renames an existing player" do
    player = Player.create!(name: "Мой Свилар", roma_profile_key: "mile-svilar")
    payload, token = preview
    row = payload.fetch("rows").find { |item| item["key"] == "mile-svilar" }
    assert_equal [ player.id ], row.fetch("candidates").pluck("id")
    PlayerRosterImport.apply!(token: token, choices: roster_choices(payload), admin: @admin)
    assert_equal "Мой Свилар", player.reload.name
  end

  test "ambiguous case variants require explicit matching" do
    one = Player.create!(name: "Миле Свилар")
    two = Player.create!(name: "миле свилар")
    payload, token = preview
    row = payload.fetch("rows").find { |item| item["key"] == "mile-svilar" }
    assert_equal "ambiguous", row.fetch("status")
    assert_equal "skip", PlayerRosterImport.default_action(row)
    choices = roster_choices(payload)
    choices["mile-svilar"]["action"] = "match:#{two.id}"
    PlayerRosterImport.apply!(token: token, choices: choices, admin: @admin)
    assert_nil one.reload.roma_profile_key
    assert_equal "mile-svilar", two.reload.roma_profile_key
  end

  test "unknown names default to skip and can be supplied in Russian" do
    snapshot = roster_snapshot
    snapshot.fetch("players") << { "key" => "future-player", "original_name" => "Future Player" }
    payload, token = preview(snapshot)
    row = payload.fetch("rows").last
    assert_equal "unknown", row.fetch("status")
    assert_equal "skip", PlayerRosterImport.default_action(row)
    choices = roster_choices(payload)
    choices["future-player"] = { "action" => "create", "name" => "Новый футболист" }
    assert_difference("Player.count", 26) { PlayerRosterImport.apply!(token: token, choices: choices, admin: @admin) }
    assert Player.exists?(roma_profile_key: "future-player", name: "Новый футболист")
  end

  test "late invalid row or duplicate edited name rolls back every player and audit entry" do
    payload, token = preview
    choices = roster_choices(payload)
    choices.fetch("mile-svilar")["name"] = " "
    assert_no_difference [ "Player.count", "AuditLog.count" ] do
      assert_raises(PlayerRosterImport::Error) { PlayerRosterImport.apply!(token: token, choices: choices, admin: @admin) }
    end
    choices.fetch("mile-svilar")["name"] = choices.values.first.fetch("name").downcase
    assert_no_difference [ "Player.count", "AuditLog.count" ] do
      assert_raises(PlayerRosterImport::Error) { PlayerRosterImport.apply!(token: token, choices: choices, admin: @admin) }
    end
  end

  test "catalog changes tampering expiration and another admin invalidate the preview" do
    payload, token = preview
    assert_raises(PlayerRosterImport::Error) { PlayerRosterImport.read(token: token + "x", admin: @admin) }
    assert_raises(PlayerRosterImport::Error) { PlayerRosterImport.read(token: token, admin: @other_user) }
    travel 31.minutes do
      assert_raises(PlayerRosterImport::Error) { PlayerRosterImport.read(token: token, admin: @admin) }
    end
    Player.create!(name: "Добавлен в другой вкладке")
    assert_no_difference("Player.count") do
      assert_raises(PlayerRosterImport::StalePreview) { PlayerRosterImport.apply!(token: token, choices: roster_choices(payload), admin: @admin) }
    end
  end

  test "unrelated candidate and forged create action are rejected" do
    player = Player.create!(name: "Миле Свилар")
    unrelated = Player.create!(name: "Другой")
    payload, token = preview
    [ "match:#{unrelated.id}", "create", "destroy" ].each do |action|
      choices = roster_choices(payload)
      choices["mile-svilar"]["action"] = action
      assert_no_difference [ "Player.count", "AuditLog.count" ] do
        assert_raises(PlayerRosterImport::Error) { PlayerRosterImport.apply!(token: token, choices: choices, admin: @admin) }
      end
      assert_nil player.reload.roma_profile_key
    end
  end

  test "conflicting profile is skipped and audit failure rolls everything back" do
    player = Player.create!(name: "Миле Свилар", roma_profile_key: "other-profile")
    payload, token = preview
    row = payload.fetch("rows").find { |item| item["key"] == "mile-svilar" }
    assert_equal "conflict", row.fetch("status")
    assert_equal "skip", PlayerRosterImport.default_action(row)
    failure = -> { raise "audit unavailable" }
    AuditLog.set_callback(:create, :before, failure)
    assert_no_difference("Player.count") do
      assert_raises(RuntimeError) { PlayerRosterImport.apply!(token: token, choices: roster_choices(payload), admin: @admin) }
    end
    assert_equal "other-profile", player.reload.roma_profile_key
  ensure
    AuditLog.skip_callback(:create, :before, failure)
  end

  test "backup failure prevents writes" do
    payload, token = preview
    with_method_override(PlayerRosterImport, :backup!, -> { raise PlayerRosterImport::Error, "Backup failed" }) do
      assert_no_difference [ "Player.count", "AuditLog.count" ] do
        assert_raises(PlayerRosterImport::Error) { PlayerRosterImport.apply!(token: token, choices: roster_choices(payload), admin: @admin) }
      end
    end
  end
end
