class AddRomaProfileKeyToPlayers < ActiveRecord::Migration[8.1]
  def change
    add_column :players, :roma_profile_key, :string
    add_index :players, :roma_profile_key, unique: true
  end
end
