class AddScoringSnapshotToMatchResults < ActiveRecord::Migration[8.1]
  def change
    add_column :match_results, :scoring_snapshot, :text
    add_column :match_results, :gold_balances_snapshot, :text
  end
end
