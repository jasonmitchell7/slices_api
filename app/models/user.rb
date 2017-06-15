class User < ActiveRecord::Base
  attr_accessor :password

  attr_accessor :accepted
  attr_accessor :follower_count
  attr_accessor :potential_follower_count
  attr_accessor :following_count
  attr_accessor :slice_count

  before_save :encrypt_password

  validates_confirmation_of :password
  validates_presence_of :email, :on => :create
  validates :password, length: { in: 6..30 }, :on => :create

  validates_format_of :email, :with => /\A[^@]+@([^@\.]+\.)+[^@\.]+\z/
  validates_uniqueness_of :email
  has_many :slices
  has_many :medias
  has_many :recipes

  has_many :participants, class_name:  "Participant",
                          foreign_key: "user_id",
                          dependent:   :destroy
  has_many :conversations, through: :participants, source: :conversation

  has_one :setting

  has_many :devices
  has_many :notifications

  has_many :active_relationships,  class_name:  "Relationship",
                                   foreign_key: "follower_id",
                                   dependent:   :destroy
  has_many :passive_relationships, class_name:  "Relationship",
                                   foreign_key: "followed_id",
                                   dependent:   :destroy
  has_many :following, through: :active_relationships,  source: :followed
  has_many :followers, through: :passive_relationships, source: :follower

  has_many :blocks
  has_many :reports


  # Follows a user.
  def follow(other_user)
    active_relationships.create(followed_id: other_user.id, accepted: !other_user.setting.require_acceptance)

    # Send notification to user
    if other_user.devices.last.present?
      sns = AWS::SNS::Client.new
      device = other_user.devices.last

      iphone_notification = {
          aps: {alert: "You have been followed by **!",
                sound: "default",
                badge: 1},
                #extra: {
                  #fol_id: self.id
                #}
              }
=begin need to redo notifications
      sns_message = {default: "A user followed another user.",
                     APNS_SANDBOX: iphone_notification.to_json,
                     APNS: iphone_notification.to_json}

      sns.publish(target_arn: device.endpoint_arn,
                  message: sns_message.to_json,
                  message_structure:"json")
=end
    end
  end

  def follow_with_id(other_user)
    active_relationships.create(followed_id: other_user)

    followed_user = User.find(other_user)

    if followed_user.devices.last.present?
      device = followed_user.devices.last

      iphone_notification = {
          aps: {alert: "You have been followed by **!",
                sound: "default",
                badge: 1},
                extra: {}
              }
=begin need to redo notifications
      sns_message = {default: "A user followed another user.",
                     APNS_SANDBOX: iphone_notification.to_json,
                     APNS: iphone_notification.to_json}

      message = sns.publish(target_arn: device.endpoint_arn,
                            message: sns_message.to_json,
                            message_structure:"json")
=end
    end
  end

  # Unfollows a user.
  def unfollow(other_user)
    active_relationships.find_by(followed_id: other_user.id).destroy
  end

  def unfollow_with_id(other_user)
    active_relationships.find_by(followed_id: other_user).destroy
  end

  # Returns true if the current user is following the other user.
  def following?(other_user)
    following.include?(other_user)
  end

  def hasAccepted?(id_of_user)
    if followers.include?(id_of_user)
      return followers.find_by(id_of_user).accepted
    else
      return false
    end
  end

  def encrypt_password
    if password.present?
      self.password_salt = BCrypt::Engine.generate_salt
      self.password_hash = BCrypt::Engine.hash_secret(password, password_salt)
    end
  end

  def self.authenticate(login_name, password)
    user = self.where("email =?", login_name).first

    if user
      puts "******************* #{password} 1"

      begin
        password = AESCrypt.decrypt(password, ENV["API_AUTH_PASSWORD"])
      rescue Exception => e
        password = nil
        puts "error - #{e.message}"
      end

      puts "******************* #{password} 2"

      if user.password_hash == BCrypt::Engine.hash_secret(password, user.password_salt)
        user
      else
        nil
      end
    else
      nil
    end
  end

  def slice_count
    self.slices.where(:conversation_id => nil, :parent_id => nil).count
  end

  def follower_count
    passive_relationships.where(:accepted => true).count
  end

  def potential_follower_count
    passive_relationships.where(:accepted => false).count
  end

  def following_count
    self.following.count
  end

  def send_confirm_email_mailer
    ConfirmEmail.confirm_email(self).deliver
  end

  def change_email(new_email)
    email_status = EmailConfirmationStatus.where(:user_id => self.id).first
    if email_status
      email_status.change_email(new_email)
    else
      EmailConfirmationStatus.create(:user_id => self.id, :new_email => new_email).change_email(new_email)
    end
  end

  def confirmation_code
    EmailConfirmationStatus.where(:user_id => self.id).first.confirmation_code
  end

  def confirm_email(code)
    EmailConfirmationStatus.where(:user_id => self.id, :confirmation_code => code).first.confirm_email
  end

  def is_email_confirmed?
    EmailConfirmationStatus.where(:user_id => self.id, :confirmation_code => nil).first.present?
  end

  def to_json(options={})
    options[:except] ||= [:id, :password_hash, :password_salt, :email_verification, :verification_code, :created_at, :updated_at]
    super(options)
  end
end
