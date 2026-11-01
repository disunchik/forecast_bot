class CreateForecastDomain < ActiveRecord::Migration[8.1]
  def change
    create_table :seasons do |t|
      t.string :name, null: false
      t.boolean :active, null: false, default: false
      t.timestamps
    end
    add_index :seasons, :name, unique: true

    create_table :competitions do |t|
      t.string :name, null: false
      t.boolean :active, null: false, default: true
      t.timestamps
    end
    add_index :competitions, :name, unique: true

    create_table :matches do |t|
      t.references :season, null: false, foreign_key: true
      t.references :competition, null: false, foreign_key: true
      t.integer :forecast_number, null: false
      t.string :opponent, null: false
      t.integer :venue, null: false, default: 0
      t.datetime :kickoff_at, null: false
      t.integer :status, null: false, default: 0
      t.timestamps
    end
    add_index :matches, [:season_id, :forecast_number], unique: true

    create_table :temporary_questions do |t|
      t.references :match, null: false, foreign_key: true, index: { unique: true }
      t.text :text, null: false
      t.integer :question_type, null: false, default: 0
      t.integer :points, null: false, default: 0
      t.boolean :voided, null: false, default: false
      t.timestamps
    end

    create_table :temporary_question_options do |t|
      t.references :temporary_question, null: false, foreign_key: true
      t.string :text, null: false
      t.boolean :correct, null: false, default: false
      t.timestamps
    end

    create_table :players do |t|
      t.string :name, null: false
      t.boolean :active, null: false, default: true
      t.timestamps
    end
    add_index :players, :name, unique: true

    create_table :forecasts do |t|
      t.references :user, null: false, foreign_key: true
      t.references :match, null: false, foreign_key: true
      t.references :temporary_question_option, foreign_key: true
      t.text :temporary_answer_text
      t.integer :halftime_roma, null: false
      t.integer :halftime_opponent, null: false
      t.integer :fulltime_roma, null: false
      t.integer :fulltime_opponent, null: false
      t.integer :first_score, null: false
      t.integer :gold_points_stake, null: false, default: 0
      t.datetime :submitted_at, null: false
      t.timestamps
    end
    add_index :forecasts, [:user_id, :match_id], unique: true

    create_table :forecast_scorers do |t|
      t.references :forecast, null: false, foreign_key: true
      t.references :player, null: false, foreign_key: true
      t.timestamps
    end
    add_index :forecast_scorers, [:forecast_id, :player_id], unique: true

    create_table :forecast_assists do |t|
      t.references :forecast, null: false, foreign_key: true
      t.references :player, foreign_key: true
      t.boolean :no_assist, null: false, default: false
      t.timestamps
    end
    add_index :forecast_assists, [:forecast_id, :player_id], unique: true

    create_table :match_results do |t|
      t.references :match, null: false, foreign_key: true, index: { unique: true }
      t.integer :halftime_roma, null: false, default: 0
      t.integer :halftime_opponent, null: false, default: 0
      t.integer :fulltime_roma, null: false, default: 0
      t.integer :fulltime_opponent, null: false, default: 0
      t.integer :first_score, null: false, default: 2
      t.integer :state, null: false, default: 0
      t.references :confirmed_by, foreign_key: { to_table: :users }
      t.datetime :confirmed_at
      t.timestamps
    end

    create_table :match_goals do |t|
      t.references :match_result, null: false, foreign_key: true
      t.references :scorer, foreign_key: { to_table: :players }
      t.references :assist, foreign_key: { to_table: :players }
      t.boolean :own_goal, null: false, default: false
      t.boolean :no_assist, null: false, default: false
      t.integer :position, null: false, default: 0
      t.timestamps
    end

    create_table :temporary_question_accepted_answers do |t|
      t.references :temporary_question, null: false, foreign_key: true
      t.text :answer_text, null: false
      t.string :normalized_answer, null: false
      t.timestamps
    end
    add_index :temporary_question_accepted_answers,
              [:temporary_question_id, :normalized_answer],
              unique: true,
              name: "idx_temp_question_accepted_answers_unique"

    create_table :forecast_scores do |t|
      t.references :forecast, null: false, foreign_key: true, index: { unique: true }
      t.references :match_result, null: false, foreign_key: true
      t.integer :halftime_difference_points, null: false, default: 0
      t.integer :halftime_exact_points, null: false, default: 0
      t.integer :fulltime_difference_points, null: false, default: 0
      t.integer :fulltime_exact_points, null: false, default: 0
      t.integer :outcome_points, null: false, default: 0
      t.integer :roma_no_goal_points, null: false, default: 0
      t.integer :nil_nil_points, null: false, default: 0
      t.integer :first_score_points, null: false, default: 0
      t.integer :scorer_points, null: false, default: 0
      t.integer :assist_points, null: false, default: 0
      t.integer :temporary_question_points, null: false, default: 0
      t.integer :base_points, null: false, default: 0
      t.integer :gold_points_applied, null: false, default: 0
      t.integer :total_points, null: false, default: 0
      t.integer :placement
      t.timestamps
    end

    create_table :achievements do |t|
      t.string :name, null: false
      t.text :description
      t.boolean :secret, null: false, default: false
      t.boolean :revealed, null: false, default: false
      t.boolean :active, null: false, default: true
      t.timestamps
    end
    add_index :achievements, :name, unique: true

    create_table :user_achievements do |t|
      t.references :user, null: false, foreign_key: true
      t.references :achievement, null: false, foreign_key: true
      t.references :awarded_by, foreign_key: { to_table: :users }
      t.datetime :awarded_at, null: false
      t.timestamps
    end
    add_index :user_achievements, [:user_id, :achievement_id], unique: true

    create_table :gold_point_transactions do |t|
      t.references :user, null: false, foreign_key: true
      t.references :season, null: false, foreign_key: true
      t.references :match, foreign_key: true
      t.references :achievement, foreign_key: true
      t.references :created_by, foreign_key: { to_table: :users }
      t.integer :kind, null: false
      t.integer :amount, null: false
      t.text :note
      t.timestamps
    end
    add_index :gold_point_transactions, [:match_id, :user_id, :kind], name: "idx_gold_transactions_match_user_kind"

    create_table :standing_snapshots do |t|
      t.references :season, null: false, foreign_key: true
      t.references :match, null: false, foreign_key: true, index: { unique: true }
      t.timestamps
    end

    create_table :standing_entries do |t|
      t.references :standing_snapshot, null: false, foreign_key: true
      t.references :user, null: false, foreign_key: true
      t.integer :group_name, null: false, default: 0
      t.integer :rank, null: false
      t.integer :points, null: false, default: 0
      t.integer :last_match_points, null: false, default: 0
      t.timestamps
    end
    add_index :standing_entries, [:standing_snapshot_id, :user_id], unique: true, name: "idx_standing_entries_snapshot_user"

    create_table :scoring_rules do |t|
      t.string :key, null: false
      t.integer :value, null: false
      t.string :label, null: false
      t.timestamps
    end
    add_index :scoring_rules, :key, unique: true

    create_table :audit_logs do |t|
      t.references :admin, foreign_key: { to_table: :users }
      t.string :action, null: false
      t.string :auditable_type
      t.integer :auditable_id
      t.text :details, null: false, default: "{}"
      t.timestamps
    end
    add_index :audit_logs, [:auditable_type, :auditable_id]
  end
end
