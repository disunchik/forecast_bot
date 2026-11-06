class AddRevocationToUserAchievements < ActiveRecord::Migration[8.1]
  def change
    add_column :user_achievements, :revoked_at, :datetime
    add_column :user_achievements, :revocation_reason, :text
    add_reference :user_achievements, :revoked_by, foreign_key: { to_table: :users }
  end
end
