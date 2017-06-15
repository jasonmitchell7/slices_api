# Preview all emails at http://localhost:3000/rails/mailers/confirm_email
class ConfirmEmailPreview < ActionMailer::Preview
  def ConfirmEmailPreview
    ConfirmEmail.confirm_email(User.first)
  end
end
