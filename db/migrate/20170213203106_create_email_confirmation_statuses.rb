class CreateEmailConfirmationStatuses < ActiveRecord::Migration
  def change
    create_table :email_confirmation_statuses do |t|
      t.integer "user_id",  null: false

      t.string "old_email"
      t.string "new_email", null: false
      t.integer "confirmation_code"

      t.timestamps
    end
  end
end
