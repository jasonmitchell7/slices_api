class Media < ActiveRecord::Base
  belongs_to :user, optional: false
  belongs_to :parent_slice, foreign_key: "slice_id", class_name: "Slice", optional: true

  enum media_type: [:default, :photo_slice, :photo_user, :video_slice]

  def to_json(options={})
    options[:except] ||= [:user_id, :created_at, :updated_at]
    super(options)
  end
end
