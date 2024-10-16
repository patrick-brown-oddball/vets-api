class CreateEmailRecords < ActiveRecord::Migration[7.1]
  def change
    create_table :email_records do |t|
      t.string :va_notify_id
      t.integer :email_type
      t.integer :email_state
      t.integer :tracked_item_id
      t.string :tracked_item_class

      t.timestamps
    end
  end
end
