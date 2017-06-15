class Conversation < ActiveRecord::Base
  has_many :participants, class_name:  "Participant",
                          foreign_key: "conversation_id",
                          dependent:   :destroy
  has_many :users, through: :participants, source: :user

  has_many :slices

end
