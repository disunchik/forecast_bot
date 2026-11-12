require "test_helper"
require_relative "../support/domain_test_helper"
require_relative "../support/roster_test_helper"

class PlayerRosterWorkflowTest < ActionDispatch::IntegrationTest
  include DomainTestHelper
  include RosterTestHelper
  setup { setup_domain }

  test "players have spaced list actions and new form focuses name but errors focus summary" do
    Player.create!(name: "Миле Свилар")
    sign_in_as(@admin)
    get admin_players_path
    assert_response :success
    assert_select ".player-list .player-row", count: 1
    assert_select "a[href=?]", admin_new_player_roster_import_path
    get new_admin_player_path
    assert_select "#player_name[autofocus]"
    post admin_players_path, params: { player: { name: "" } }
    assert_response :unprocessable_entity
    assert_select "[role=alert][autofocus]"
    assert_select "#player_name[autofocus]", count: 0
  end

  test "saved import is explicitly chosen read only until apply and preserves existing inactive player" do
    player = Player.create!(name: "Дэвис Васкес", active: false)
    sign_in_as(@admin)
    get admin_new_player_roster_import_path
    assert_response :success
    assert_select "input[value=saved]"
    assert_no_difference [ "Player.count", "AuditLog.count" ] do
      post admin_preview_player_roster_import_path, params: { source: "saved" }
    end
    assert_response :success
    assert_match "Сохранённая копия", response.body
    assert_select "#roster-devis-vasquez", text: /неактивен/
    token = css_select("input[name=preview_token]").sole["value"]
    preview = PlayerRosterImport.read(token: token, admin: @admin)
    assert_difference("Player.count", 24) do
      post admin_player_roster_import_path, params: { preview_token: token, rows: roster_choices(preview) }
    end
    assert_redirected_to admin_players_path
    assert_not player.reload.active?
    assert_equal "Дэвис Васкес", player.name
    assert_equal "devis-vasquez", player.roma_profile_key
    assert_no_difference("Player.count") do
      post admin_player_roster_import_path, params: { preview_token: token, rows: roster_choices(preview) }
    end
    assert_response :unprocessable_entity
  end

  test "live fixture preview works and source failure offers an explicit saved alternative" do
    sign_in_as(@admin)
    fixture = roster_snapshot.merge("source" => "live")
    with_method_override(RomaRosterSource, :live, -> { fixture }) do
      post admin_preview_player_roster_import_path, params: { source: "live" }
      assert_response :success
      assert_match "Получено с сайта клуба", response.body
      assert_select ".player-import-row", count: 25
    end
    with_method_override(RomaRosterSource, :live, -> { raise RomaRosterSource::Error, "Сайт недоступен" }) do
      assert_no_difference("Player.count") { post admin_preview_player_roster_import_path, params: { source: "live" } }
      assert_response :unprocessable_entity
      assert_select "[role=alert]", text: "Сайт недоступен"
      assert_select "input[value=saved]"
      assert_select ".player-import-row", count: 0
    end
  end

  test "regular users cannot open preview fetch or apply an import" do
    sign_in_as(@user)
    get admin_new_player_roster_import_path
    assert_redirected_to root_path
    assert_no_difference [ "Player.count", "AuditLog.count" ] do
      post admin_preview_player_roster_import_path, params: { source: "saved" }
      assert_redirected_to root_path
      post admin_player_roster_import_path, params: { preview_token: "invalid" }
      assert_redirected_to root_path
    end
  end

  test "invalid submitted row preserves valid input and renders recoverable errors" do
    sign_in_as(@admin)
    payload, token = PlayerRosterImport.preview(snapshot: roster_snapshot, admin: @admin)
    choices = roster_choices(payload)
    choices["mile-svilar"] = "invalid"
    assert_no_difference("Player.count") do
      post admin_player_roster_import_path, params: { preview_token: token, rows: choices }
    end
    assert_response :unprocessable_entity
    assert_select "[role=alert]"
    assert_select ".player-import-row", count: 25
  end
end
