class CreateMedia < ActiveRecord::Migration
  def change
    drop_table :photos
    drop_table :videos

    create_table :media do |t|
      t.string  "url"
      t.string  "name"
      t.integer "user_id"
      t.integer "slice_id"
      t.integer "seq", default: 0
      t.integer "media_type", default: 0
      t.integer "duration", default: 2

      t.string   "random_id"

      t.timestamps
    end
  end
end
