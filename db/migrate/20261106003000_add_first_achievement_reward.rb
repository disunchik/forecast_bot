class AddFirstAchievementReward < ActiveRecord::Migration[8.1]
  def change
    add_column :achievements, :first_award_points, :integer
  end
end
