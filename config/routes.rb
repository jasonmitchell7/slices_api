Rails.application.routes.draw do
  root 'home#index'

  get 'home/index'

  # Authentication endpoints
  post 'api/signup'
  post 'api/signin'
  post 'api/reset_password'

  get 'api/get_token'
  get 'api/clear_token'

  # Email endpoints
  post 'api/confirm_email'
  post 'api/resend_confirm_email'
  post 'api/change_email'
  get 'api/confirm_email_with_address'

  # Media endpoints
  post 'api/upload_media'
  delete 'api/delete_media'

  get 'api/get_media_with_id'

  # Relationship endpoints
  post 'api/follow_user'
  post 'api/unfollow_user'
  post 'api/accept_follow'
  post 'api/decline_follow'
  post 'api/request_followers'
  post 'api/request_following'

  # Settings endpoints
  get 'api/request_settings_info'
  post 'api/update_settings_info'

  # User endpoints
  post 'api/find_user'
  post 'api/update_description'
  post 'api/request_user_info'

  # Slice endpoints
  post 'api/post_slice'
  post 'api/publish_slice'

  get 'api/get_slices'
  get 'api/get_toppings'

  get 'api/get_slice_media_list'

  # Convo endpoints
  get 'api/get_convos'
  post 'api/create_convo'
  post 'api/leave_convo'
  post 'api/change_convo_notifications'

  # Notification endpoints
  post 'api/new_device_token'

  match "*path", to: "application#page_not_found", via: :all
end
