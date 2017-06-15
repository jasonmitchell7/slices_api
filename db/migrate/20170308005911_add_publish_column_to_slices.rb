class AddPublishColumnToSlices < ActiveRecord::Migration[5.0]
  def change
    change_table :slices do |t|
      t.boolean "published", default: false
      t.datetime "published_at"
    end
  end
end
