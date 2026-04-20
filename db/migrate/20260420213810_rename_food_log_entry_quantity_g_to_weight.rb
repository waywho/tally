class RenameFoodLogEntryQuantityGToWeight < ActiveRecord::Migration[8.1]
  def change
    rename_column :food_log_entries, :quantity_g, :weight
  end
end
