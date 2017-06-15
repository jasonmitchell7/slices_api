class ConfirmEmail < ActionMailer::Base
  default from: "jasonmitchell@slicesof.life"

  def confirm_email(user)
    @user = user
    mail(to: @user.email, subject: 'Welcome to Slices!')
  end
end
