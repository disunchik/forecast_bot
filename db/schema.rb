# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# This file is the source Rails uses to define your schema when running `bin/rails
# db:schema:load`. When creating a new database, `bin/rails db:schema:load` tends to
# be faster and is potentially less error prone than running all of your
# migrations from scratch. Old migrations may fail to apply correctly if those
# migrations use external dependencies or application code.
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema[8.1].define(version: 2026_11_01_190000) do
  create_table "achievements", force: :cascade do |t|
    t.boolean "active", default: true, null: false
    t.datetime "created_at", null: false
    t.text "description"
    t.string "name", null: false
    t.boolean "revealed", default: false, null: false
    t.boolean "secret", default: false, null: false
    t.datetime "updated_at", null: false
    t.index ["name"], name: "index_achievements_on_name", unique: true
  end

  create_table "audit_logs", force: :cascade do |t|
    t.string "action", null: false
    t.integer "admin_id"
    t.integer "auditable_id"
    t.string "auditable_type"
    t.datetime "created_at", null: false
    t.text "details", default: "{}", null: false
    t.datetime "updated_at", null: false
    t.index ["admin_id"], name: "index_audit_logs_on_admin_id"
    t.index ["auditable_type", "auditable_id"], name: "index_audit_logs_on_auditable_type_and_auditable_id"
  end

  create_table "competitions", force: :cascade do |t|
    t.boolean "active", default: true, null: false
    t.datetime "created_at", null: false
    t.string "name", null: false
    t.datetime "updated_at", null: false
    t.index ["name"], name: "index_competitions_on_name", unique: true
  end

  create_table "forecast_assists", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.integer "forecast_id", null: false
    t.boolean "no_assist", default: false, null: false
    t.integer "player_id"
    t.datetime "updated_at", null: false
    t.index ["forecast_id", "player_id"], name: "index_forecast_assists_on_forecast_id_and_player_id", unique: true
    t.index ["forecast_id"], name: "index_forecast_assists_on_forecast_id"
    t.index ["player_id"], name: "index_forecast_assists_on_player_id"
  end

  create_table "forecast_scorers", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.integer "forecast_id", null: false
    t.integer "player_id", null: false
    t.datetime "updated_at", null: false
    t.index ["forecast_id", "player_id"], name: "index_forecast_scorers_on_forecast_id_and_player_id", unique: true
    t.index ["forecast_id"], name: "index_forecast_scorers_on_forecast_id"
    t.index ["player_id"], name: "index_forecast_scorers_on_player_id"
  end

  create_table "forecast_scores", force: :cascade do |t|
    t.integer "assist_points", default: 0, null: false
    t.integer "base_points", default: 0, null: false
    t.datetime "created_at", null: false
    t.integer "first_score_points", default: 0, null: false
    t.integer "forecast_id", null: false
    t.integer "fulltime_difference_points", default: 0, null: false
    t.integer "fulltime_exact_points", default: 0, null: false
    t.integer "gold_points_applied", default: 0, null: false
    t.integer "halftime_difference_points", default: 0, null: false
    t.integer "halftime_exact_points", default: 0, null: false
    t.integer "match_result_id", null: false
    t.integer "nil_nil_points", default: 0, null: false
    t.integer "outcome_points", default: 0, null: false
    t.integer "placement"
    t.integer "roma_no_goal_points", default: 0, null: false
    t.integer "scorer_points", default: 0, null: false
    t.integer "temporary_question_points", default: 0, null: false
    t.integer "total_points", default: 0, null: false
    t.datetime "updated_at", null: false
    t.index ["forecast_id"], name: "index_forecast_scores_on_forecast_id", unique: true
    t.index ["match_result_id"], name: "index_forecast_scores_on_match_result_id"
  end

  create_table "forecasts", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.integer "first_score", null: false
    t.integer "fulltime_opponent", null: false
    t.integer "fulltime_roma", null: false
    t.integer "gold_points_stake", default: 0, null: false
    t.integer "halftime_opponent", null: false
    t.integer "halftime_roma", null: false
    t.integer "match_id", null: false
    t.datetime "submitted_at", null: false
    t.text "temporary_answer_text"
    t.integer "temporary_question_option_id"
    t.datetime "updated_at", null: false
    t.integer "user_id", null: false
    t.index ["match_id"], name: "index_forecasts_on_match_id"
    t.index ["temporary_question_option_id"], name: "index_forecasts_on_temporary_question_option_id"
    t.index ["user_id", "match_id"], name: "index_forecasts_on_user_id_and_match_id", unique: true
    t.index ["user_id"], name: "index_forecasts_on_user_id"
  end

  create_table "gold_point_transactions", force: :cascade do |t|
    t.integer "achievement_id"
    t.integer "amount", null: false
    t.datetime "created_at", null: false
    t.integer "created_by_id"
    t.integer "kind", null: false
    t.integer "match_id"
    t.text "note"
    t.integer "season_id", null: false
    t.datetime "updated_at", null: false
    t.integer "user_id", null: false
    t.index ["achievement_id"], name: "index_gold_point_transactions_on_achievement_id"
    t.index ["created_by_id"], name: "index_gold_point_transactions_on_created_by_id"
    t.index ["match_id", "user_id", "kind"], name: "idx_gold_transactions_match_user_kind"
    t.index ["match_id"], name: "index_gold_point_transactions_on_match_id"
    t.index ["season_id"], name: "index_gold_point_transactions_on_season_id"
    t.index ["user_id"], name: "index_gold_point_transactions_on_user_id"
  end

  create_table "match_goals", force: :cascade do |t|
    t.integer "assist_id"
    t.datetime "created_at", null: false
    t.integer "match_result_id", null: false
    t.boolean "no_assist", default: false, null: false
    t.boolean "own_goal", default: false, null: false
    t.integer "position", default: 0, null: false
    t.integer "scorer_id"
    t.datetime "updated_at", null: false
    t.index ["assist_id"], name: "index_match_goals_on_assist_id"
    t.index ["match_result_id"], name: "index_match_goals_on_match_result_id"
    t.index ["scorer_id"], name: "index_match_goals_on_scorer_id"
  end

  create_table "match_results", force: :cascade do |t|
    t.datetime "confirmed_at"
    t.integer "confirmed_by_id"
    t.datetime "created_at", null: false
    t.integer "first_score", default: 2, null: false
    t.integer "fulltime_opponent", default: 0, null: false
    t.integer "fulltime_roma", default: 0, null: false
    t.text "gold_balances_snapshot"
    t.integer "halftime_opponent", default: 0, null: false
    t.integer "halftime_roma", default: 0, null: false
    t.integer "match_id", null: false
    t.text "scoring_snapshot"
    t.integer "state", default: 0, null: false
    t.datetime "updated_at", null: false
    t.index ["confirmed_by_id"], name: "index_match_results_on_confirmed_by_id"
    t.index ["match_id"], name: "index_match_results_on_match_id", unique: true
  end

  create_table "matches", force: :cascade do |t|
    t.integer "competition_id", null: false
    t.datetime "created_at", null: false
    t.integer "forecast_number", null: false
    t.datetime "kickoff_at", null: false
    t.string "opponent", null: false
    t.integer "season_id", null: false
    t.integer "status", default: 0, null: false
    t.datetime "updated_at", null: false
    t.integer "venue", default: 0, null: false
    t.index ["competition_id"], name: "index_matches_on_competition_id"
    t.index ["season_id", "forecast_number"], name: "index_matches_on_season_id_and_forecast_number", unique: true
    t.index ["season_id"], name: "index_matches_on_season_id"
  end

  create_table "players", force: :cascade do |t|
    t.boolean "active", default: true, null: false
    t.datetime "created_at", null: false
    t.string "name", null: false
    t.datetime "updated_at", null: false
    t.index ["name"], name: "index_players_on_name", unique: true
  end

  create_table "scoring_rules", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "key", null: false
    t.string "label", null: false
    t.datetime "updated_at", null: false
    t.integer "value", null: false
    t.index ["key"], name: "index_scoring_rules_on_key", unique: true
  end

  create_table "seasons", force: :cascade do |t|
    t.boolean "active", default: false, null: false
    t.datetime "created_at", null: false
    t.string "name", null: false
    t.datetime "updated_at", null: false
    t.index ["name"], name: "index_seasons_on_name", unique: true
  end

  create_table "sessions", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "ip_address"
    t.datetime "updated_at", null: false
    t.string "user_agent"
    t.integer "user_id", null: false
    t.index ["user_id"], name: "index_sessions_on_user_id"
  end

  create_table "standing_entries", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.integer "group_name", default: 0, null: false
    t.integer "last_match_points", default: 0, null: false
    t.integer "points", default: 0, null: false
    t.integer "rank", null: false
    t.integer "standing_snapshot_id", null: false
    t.datetime "updated_at", null: false
    t.integer "user_id", null: false
    t.index ["standing_snapshot_id", "user_id"], name: "idx_standing_entries_snapshot_user", unique: true
    t.index ["standing_snapshot_id"], name: "index_standing_entries_on_standing_snapshot_id"
    t.index ["user_id"], name: "index_standing_entries_on_user_id"
  end

  create_table "standing_snapshots", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.integer "match_id", null: false
    t.integer "season_id", null: false
    t.datetime "updated_at", null: false
    t.index ["match_id"], name: "index_standing_snapshots_on_match_id", unique: true
    t.index ["season_id"], name: "index_standing_snapshots_on_season_id"
  end

  create_table "temporary_question_accepted_answers", force: :cascade do |t|
    t.text "answer_text", null: false
    t.datetime "created_at", null: false
    t.string "normalized_answer", null: false
    t.integer "temporary_question_id", null: false
    t.datetime "updated_at", null: false
    t.index ["temporary_question_id", "normalized_answer"], name: "idx_temp_question_accepted_answers_unique", unique: true
    t.index ["temporary_question_id"], name: "idx_on_temporary_question_id_774511e91a"
  end

  create_table "temporary_question_options", force: :cascade do |t|
    t.boolean "correct", default: false, null: false
    t.datetime "created_at", null: false
    t.integer "temporary_question_id", null: false
    t.string "text", null: false
    t.datetime "updated_at", null: false
    t.index ["temporary_question_id"], name: "index_temporary_question_options_on_temporary_question_id"
  end

  create_table "temporary_questions", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.integer "match_id", null: false
    t.integer "points", default: 0, null: false
    t.integer "question_type", default: 0, null: false
    t.text "text", null: false
    t.datetime "updated_at", null: false
    t.boolean "voided", default: false, null: false
    t.index ["match_id"], name: "index_temporary_questions_on_match_id", unique: true
  end

  create_table "user_achievements", force: :cascade do |t|
    t.integer "achievement_id", null: false
    t.datetime "awarded_at", null: false
    t.integer "awarded_by_id"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.integer "user_id", null: false
    t.index ["achievement_id"], name: "index_user_achievements_on_achievement_id"
    t.index ["awarded_by_id"], name: "index_user_achievements_on_awarded_by_id"
    t.index ["user_id", "achievement_id"], name: "index_user_achievements_on_user_id_and_achievement_id", unique: true
    t.index ["user_id"], name: "index_user_achievements_on_user_id"
  end

  create_table "users", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "email_address"
    t.boolean "legacy_account", default: false, null: false
    t.boolean "must_change_password", default: false, null: false
    t.string "nickname", null: false
    t.string "nickname_key", null: false
    t.boolean "notify_forecast_open", default: true, null: false
    t.boolean "notify_forecast_reminder", default: true, null: false
    t.boolean "notify_results", default: true, null: false
    t.boolean "notify_rewards", default: true, null: false
    t.string "password_digest", null: false
    t.integer "role", default: 0, null: false
    t.datetime "updated_at", null: false
    t.index ["email_address"], name: "index_users_on_email_address", unique: true
    t.index ["nickname"], name: "index_users_on_nickname", unique: true
    t.index ["nickname_key"], name: "index_users_on_nickname_key", unique: true
  end

  add_foreign_key "audit_logs", "users", column: "admin_id"
  add_foreign_key "forecast_assists", "forecasts"
  add_foreign_key "forecast_assists", "players"
  add_foreign_key "forecast_scorers", "forecasts"
  add_foreign_key "forecast_scorers", "players"
  add_foreign_key "forecast_scores", "forecasts"
  add_foreign_key "forecast_scores", "match_results"
  add_foreign_key "forecasts", "matches"
  add_foreign_key "forecasts", "temporary_question_options"
  add_foreign_key "forecasts", "users"
  add_foreign_key "gold_point_transactions", "achievements"
  add_foreign_key "gold_point_transactions", "matches"
  add_foreign_key "gold_point_transactions", "seasons"
  add_foreign_key "gold_point_transactions", "users"
  add_foreign_key "gold_point_transactions", "users", column: "created_by_id"
  add_foreign_key "match_goals", "match_results"
  add_foreign_key "match_goals", "players", column: "assist_id"
  add_foreign_key "match_goals", "players", column: "scorer_id"
  add_foreign_key "match_results", "matches"
  add_foreign_key "match_results", "users", column: "confirmed_by_id"
  add_foreign_key "matches", "competitions"
  add_foreign_key "matches", "seasons"
  add_foreign_key "sessions", "users"
  add_foreign_key "standing_entries", "standing_snapshots"
  add_foreign_key "standing_entries", "users"
  add_foreign_key "standing_snapshots", "matches"
  add_foreign_key "standing_snapshots", "seasons"
  add_foreign_key "temporary_question_accepted_answers", "temporary_questions"
  add_foreign_key "temporary_question_options", "temporary_questions"
  add_foreign_key "temporary_questions", "matches"
  add_foreign_key "user_achievements", "achievements"
  add_foreign_key "user_achievements", "users"
  add_foreign_key "user_achievements", "users", column: "awarded_by_id"
end
