class Slice < ActiveRecord::Base
	belongs_to :user
	belongs_to :parent, :class_name => 'Slice'
	has_many :toppings, :foreign_key => 'parent_id',
						:class_name => 'Slice'
	has_one :conversation
	has_many :media

	def username
		user.username
	end

	def user_photo_id
		user.photo_id
	end

	def toppings_count
		self.toppings.count
	end

	def media_list
		Media.where(:slice_id => id)
	end

end
