class EmailConfirmationStatus < ActiveRecord::Base

  belongs_to :user

  def change_email(new_email)
    new_code = Random.rand(100000..999999)

    if (self.confirmation_code.nil?)
      self.update_attributes(
        :old_email => self.new_email,
        :confirmation_code => new_code,
        :new_email => new_email
      )
    else
      self.update_attributes(
        :confirmation_code => new_code,
        :new_email => new_email
      )
    end

    user.send_confirm_email_mailer
  end

  def confirm_email
    myuser = User.find(self.user_id)
    if myuser
      myuser.update_attributes(:email => self.new_email)
      self.update_attributes(
        :old_email => self.new_email,
        :confirmation_code => nil
      )
    end
  end
end
