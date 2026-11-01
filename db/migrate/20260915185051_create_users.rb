class CreateUsers < ActiveRecord::Migration[8.1]
  def change
    create_table :users do |t|
      t.string :email_address
      t.string :password_digest, null: false
      t.string :nickname, null: false
      t.string :nickname_key, null: false
      t.integer :role, null: false, default: 0
      t.boolean :legacy_account, null: false, default: false
      t.boolean :must_change_password, null: false, default: false
      t.boolean :notify_forecast_open, null: false, default: true
      t.boolean :notify_forecast_reminder, null: false, default: true
      t.boolean :notify_results, null: false, default: true
      t.boolean :notify_rewards, null: false, default: true

      t.timestamps
    end

    add_index :users, :nickname, unique: true
    add_index :users, :nickname_key, unique: true
    add_index :users, :email_address, unique: true
  end
end
