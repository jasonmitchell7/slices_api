class SliceStructureChange < ActiveRecord::Migration
  def change
    change_table :slices do |t|
      t.remove :media_id, :is_video, :reported, :height, :width
    end
  end
end
