class AddAutomaticAchievementsAndSeasonCompletion < ActiveRecord::Migration[8.1]
  def change
    add_column :seasons, :completed_at, :datetime
    add_reference :seasons, :completed_by, foreign_key: { to_table: :users }
    add_column :achievements, :rule_key, :string
    add_column :achievements, :competition_ids, :text, default: "[]", null: false
    add_reference :achievements, :first_award_season, foreign_key: { to_table: :seasons }
    add_column :achievements, :first_award_round, :integer
  end
end
