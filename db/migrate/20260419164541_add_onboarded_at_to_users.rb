class AddOnboardedAtToUsers < ActiveRecord::Migration[8.1]
  def change
    add_column :users, :onboarded_at, :datetime, null: true, default: nil
    reversible do |dir|
      dir.up do
        User.update_all(onboarded_at: Time.current)
      end
    end
  end
end
