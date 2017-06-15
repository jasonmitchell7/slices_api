class ApiController < ApplicationController
  http_basic_authenticate_with name:ENV["API_AUTH_NAME"], password:ENV["API_AUTH_PASSWORD"], :only => [:signup, :signin, :get_token]
  before_filter :check_for_valid_authtoken, :except => [:signup, :signin, :get_token, :confirm_email_with_address]
  skip_before_filter  :verify_authenticity_token

  def signup
    if request.post?
      if params && params[:username] && params[:email] && params[:password] && params[:birthdate]

        params[:user] = Hash.new
        params[:user][:username] = params[:username]
        params[:user][:email] = params[:email]
        params[:user][:birthdate] = Date.strptime(params[:birthdate], "%d-%m-%Y")

        begin
          decrypted_pass = AESCrypt.decrypt(params[:password], ENV["API_AUTH_PASSWORD"])
        rescue Exception => e
          decrypted_pass = nil
        end

        params[:user][:password] = decrypted_pass
        params[:user][:verification_code] = rand_string(20)

        user = User.new(user_params)

        if user.save
          # Call change e-mail to generate confirmation code and send mailer.
          user.change_email(user.email)
          # Create initial user settings
          Setting.create(:user_id => user.id)

          render :json => user.to_json, :status => 200
        else
          error_str = ""

          user.errors.each{|attr, msg|
            error_str += "#{attr} - #{msg},"
          }

          e = Error.new(:status => 400, :message => error_str)
          render :json => e.to_json, :status => 400
        end
      else
        e = Error.new(:status => 400, :message => "Missing required parameters.")
        render :json => e.to_json, :status => 400
      end
    end
  end

  def signin
    if request.post?
      if params && params[:email] && params[:password]
        user = User.where(:email => params[:email]).first

        if user
          if User.authenticate(params[:email], params[:password])

            if !user.api_authtoken || (user.api_authtoken && user.authtoken_expiry < Time.now)
              auth_token = rand_string(20)
              auth_expiry = Time.now + (24*60*60)

              user.update_attributes(:api_authtoken => auth_token, :authtoken_expiry => auth_expiry)
            end

            render :json => user.to_json(:only => [:api_authtoken, :authtoken_expiry]), :status => 200
          else
            e = Error.new(:status => 401, :message => "Incorrect password.")
            render :json => e.to_json, :status => 401
          end
        else
          e = Error.new(:status => 402, :message => "No user found by this email ID.")
          render :json => e.to_json, :status => 402
        end
      else
        e = Error.new(:status => 409, :message => "Missing required parameters.")
        render :json => e.to_json, :status => 409
      end
    end
  end

  def confirm_email
    if request.post?
      if @user && @user.authtoken_expiry > Time.now
        if params && params[:code]
          @user.confirm_email(params[:code])

          if @user.is_email_confirmed?
            m = Message.new(:status => 200, :message => "Email confirmed.")
            render :json => m.to_json, :status => 200
          else
            m = Message.new(:status => 400, :message => "Could not confirm email.")
            render :json => m.to_json, :status => 400
          end
        else
          e = Error.new(:status => 409, :message => "Missing required parameters.")
          render :json => e.to_json, :status => 409
        end
      end
    else
      e = Error.new(:status => 400, :message => "Invalid request.")
      render :json => e.to_json, :status => 400
    end
  end

  def confirm_email_with_address
    if request.get?
      if params && params[:email] && params[:code]
        # This is a request from the web or an e-mail link.
        email_status = EmailConfirmationStatus.where(
                                                      :new_email => params[:email],
                                                      :confirmation_code => params[:code]
                                                    ).first

        user = nil

        if email_status
          user = User.find(email_status.user_id)
        end

        if user
          email_status.confirm_email()

          if user.is_email_confirmed?
            m = Message.new(:status => 200, :message => "Email confirmed.")
            render :json => m.to_json, :status => 200
          else
            m = Message.new(:status => 400, :message => "Could not confirm email.")
            render :json => m.to_json, :status => 400
          end
        else
          m = Message.new(:status => 400, :message => "Invalid params.")
          render :json => m.to_json, :status => 400
        end
      else
        e = Error.new(:status => 409, :message => "Missing required parameters.")
        render :json => e.to_json, :status => 409
      end
    else
      e = Error.new(:status => 400, :message => "Invalid request.")
      render :json => e.to_json, :status => 400
    end
  end

  def resend_confirm_email
    if request.post?
      if @user && @user.authtoken_expiry > Time.now
        if @user.is_email_confirmed?
          e = Error.new(:status => 400, :message => "Email already confirmed.")
          render :json => e.to_json, :status => 400
        else
          @user.send_confirm_email_mailer

          m = Message.new(:status => 200, :message => "Confirmation code sent.")
          render :json => m.to_json, :status => 200
        end
      else
        e = Error.new(:status => 401, :message => "Authtoken has expired.")
        render :json => e.to_json, :status => 401
      end
    end
  end

  def change_email
    if request.post?
      if @user && @user.authtoken_expiry > Time.now
        if params && params[:new_email]
          if (User.where(:email => params[:new_email]).empty? &&
              EmailConfirmationStatus.where(:old_email => params[:new_email]).empty? &&
              EmailConfirmationStatus.where(:new_email => params[:new_email]).empty?)
                @user.change_email

                m = Message.new(:status => 200, :message => "New confirmation code sent.")
                render :json => m.to_json, :status => 200
          else
            e = Error.new(:status => 400, :message => "Email already exists.")
            render :json => e.to_json, :status => 400
          end
        else
          e = Error.new(:status => 409, :message => "Missing required parameters.")
          render :json => e.to_json, :status => 409
        end
      else
        e = Error.new(:status => 401, :message => "Authtoken has expired.")
        render :json => e.to_json, :status => 401
      end
    end
  end

  def reset_password
    if request.post?
      if params && params[:old_password] && params[:new_password]
        if @user
          if @user.authtoken_expiry > Time.now
            authenticate_user = User.authenticate(@user.email, params[:old_password])

            if authenticate_user && !authenticate_user.nil?
              auth_token = rand_string(20)
              auth_expiry = Time.now + (24*60*60)

              begin
                new_password = AESCrypt.decrypt(params[:new_password], ENV["API_AUTH_PASSWORD"])
              rescue Exception => e
                new_password = nil
                puts "error - #{e.message}"
              end

              new_password_salt = BCrypt::Engine.generate_salt
              new_password_digest = BCrypt::Engine.hash_secret(new_password, new_password_salt)

              @user.update_attributes(:password => new_password, :api_authtoken => auth_token, :authtoken_expiry => auth_expiry, :password_salt => new_password_salt, :password_hash => new_password_digest)
              render :json => @user.to_json, :status => 200
            else
              e = Error.new(:status => 401, :message => "Wrong Password")
              render :json => e.to_json, :status => 401
            end
          else
            e = Error.new(:status => 401, :message => "Authtoken is invalid or has expired. Kindly refresh the token and try again!")
            render :json => e.to_json, :status => 401
          end
        else
          e = Error.new(:status => 400, :message => "No user record found for this email ID")
          render :json => e.to_json, :status => 400
        end
      else
        e = Error.new(:status => 400, :message => "required parameters are missing")
        render :json => e.to_json, :status => 400
      end
    end
  end

  def get_token
    if params && params[:email]
      user = User.where(:email => params[:email]).first

      if user
        if !user.api_authtoken || (user.api_authtoken && user.authtoken_expiry < Time.now)
          auth_token = rand_string(20)
          auth_expiry = Time.now + (24*60*60)

          user.update_attributes(:api_authtoken => auth_token, :authtoken_expiry => auth_expiry)
        end

        render :json => user.to_json(:only => [:api_authtoken, :authtoken_expiry])
      else
        e = Error.new(:status => 400, :message => "No user record found for this email ID")
        render :json => e.to_json, :status => 400
      end

    else
      e = Error.new(:status => 400, :message => "required parameters are missing")
      render :json => e.to_json, :status => 400
    end
  end

  def clear_token
    if @user.api_authtoken && @user.authtoken_expiry > Time.now
      @user.update_attributes(:api_authtoken => nil, :authtoken_expiry => nil)

      m = Message.new(:status => 200, :message => "Token cleared")
      render :json => m.to_json, :status => 200
    else
      e = Error.new(:status => 401, :message => "You don't have permission to do this task")
      render :json => e.to_json, :status => 401
    end
  end

  def upload_media
    if request.post?
      if params[:media] && (
          (params[:type] == "photo_user") ||
            ((params[:type] == "photo_slice" || params[:type] == "video_slice") && params[:slice_id])
          )
        if @user && @user.authtoken_expiry > Time.now
          rand_id = rand_string(40)

          if (params[:type] == "video_slice")
            rand_id = "v_" + rand_id
          else
            rand_id = "p_" + rand_id
          end

          media_name = params[:media].original_filename
          media = params[:media].read

          s3 = AWS::S3.new

          if s3
            bucket = s3.buckets[ENV["S3_BUCKET_NAME"]]

            if !bucket
              bucket = s3.buckets.create(ENV["S3_BUCKET_NAME"])
            end

            s3_obj = bucket.objects[rand_id]
            s3_obj.write(media, :acl => :public_read)
            url = s3_obj.public_url.to_s

            media = Media.new(
              :name => media_name,
              :user_id => @user.id,
              :url => url,
              :random_id => rand_id,
              :media_type => params[:type]
            )

            if (params[:slice_id])
              media.update_attributes(:slice_id => params[:slice_id])
            end

            if media.save
              if (params[:type] == "photo_user")
                if !@user.photo_id.nil?
                  old_photo = Media.where(:random_id => @user.photo_id).first

                  if old_photo.present?

                    s3_old_obj =  bucket.objects[old_photo.random_id]
                    s3_old_obj.delete

                    old_photo.destroy
                  end
                end

                @user.update_attributes(:photo_id => rand_id)
              end

              render :json => media.to_json, :status => 200
            else
              error_str = ""

              media.errors.each{|attr, msg|
                error_str += "#{attr} - #{msg},"
              }

              e = Error.new(:status => 400, :message => error_str)
              render :json => e.to_json, :status => 400
            end
          else
            e = Error.new(:status => 401, :message => "Could not connect to CDN.")
            render :json => e.to_json, :status => 401
          end
        else
          e = Error.new(:status => 401, :message => "Authtoken was invalid or expired.")
          render :json => e.to_json, :status => 401
        end
      else
        e = Error.new(:status => 400, :message => "Missing required parameters.")
        render :json => e.to_json, :status => 400
      end
    end
  end

  def post_slice
    if request.post?
      if params[:title]
        if @user && @user.authtoken_expiry > Time.now

          slice = Slice.new(:user_id => @user.id, :title => params[:title])

          if params[:parent_id]
            slice.assign_attributes(:parent_id => params[:parent_id])
          end

          if params[:location_string] && params[:longitude] && params[:latitude]
            slice.assign_attributes(:location_string => params[:location_string],
                                    :longitude => params[:longitude],
                                    :latitude => params[:latitude])
          end

          if slice.save
            render :json => slice.to_json, :status => 200
          else
            e = Error.new(:status => 401, :message => "Failed to post slice to server.")
            render :json => e.to_json, :status => 401
          end

        else
          e = Error.new(:status => 401, :message => "Authtoken has expired.")
          render :json => e.to_json, :status => 401
        end
      else
        e = Error.new(:status => 400, :message => "Missing required parameters.")
        render :json => e.to_json, :status => 400
      end
    else
      e = Error.new(:status => 400, :message => "Invalid request type.")
      render :json => e.to_json, :status => 400
    end
  end

  def publish_slice
    if request.post?
      if params[:slice_id]
        if @user && @user.authtoken_expiry > Time.now
          slice = Slice.find(slice_id)

          if (slice)
            if(slice.user_id == @user.id)
              slice.update_attributes(
                :published => true,
                :published_at => DateTime.now
              )

              m = Message.new(:status => 200, :message => "Slice published!")
              render :json => m.to_json, :status => 200
            else
              e = Error.new(:status => 400, :message => "Invalid permission to publish Slice.")
              render :json => e.to_json, :status => 400
            end
          else
            e = Error.new(:status => 400, :message => "Invalid Slice ID.")
            render :json => e.to_json, :status => 400
          end
        else
          e = Error.new(:status => 401, :message => "Authtoken has expired.")
          render :json => e.to_json, :status => 401
        end
      else
        e = Error.new(:status => 400, :message => "Missing required parameters.")
        render :json => e.to_json, :status => 400
      end
    else
      e = Error.new(:status => 400, :message => "Invalid request type.")
      render :json => e.to_json, :status => 400
    end
  end

  # TODO: Change to delete Slice endpoint.
  def delete_media
    if request.delete?
      if params[:media_id]
        if @user && @user.authtoken_expiry > Time.now
          media = Media.where(:random_id => params[:media_id]).first

          if media && media.user_id == @user.id
            s3 = AWS::S3.new

            if s3
              bucket = s3.buckets[ENV["S3_BUCKET_NAME"]]
              s3_obj =  bucket.objects[media.random_id]
              s3_obj.delete

              media.destroy

              m = Message.new(:status => 200, :message => "Media was successfully deleted.")
              render :json => m.to_json, :status => 200
            else
              e = Error.new(:status => 401, :message => "AWS S3 signature is wrong")
              render :json => e.to_json, :status => 401
            end
          else
            e = Error.new(:status => 401, :message => "Invalid media ID or You don't have permission to delete this media!")
            render :json => e.to_json, :status => 401
          end
        else
          e = Error.new(:status => 401, :message => "Authtoken has expired. Please get a new token and try again!")
          render :json => e.to_json, :status => 401
        end
      else
        e = Error.new(:status => 400, :message => "required parameters are missing")
        render :json => e.to_json, :status => 400
      end
    end
  end

  def get_media_with_id
    if @user && @user.authtoken_expiry > Time.now
      if params[:requested_id]

        media = Media.where(:random_id => params[:requested_id]).first

        if media.present?
          render :json => media.to_json, :status => 200
        else
          e = Error.new(:status => 401, :message => "Could not find media." + params[:requested_id])
          render :json => e.to_json, :status => 401
        end
      else
        e = Error.new(:status => 401, :message => "Missing required parameters.")
        render :json => e.to_json, :status => 401
      end
    else
      e = Error.new(:status => 401, :message => "Authtoken has expired. Please get a new token and try again!")
      render :json => e.to_json, :status => 401
    end
  end

  def get_slices
    if @user && @user.authtoken_expiry > Time.now && params[:count]

      if params[:convo_id]
        to_send = Slice.where(
          :user_id => User.find(@user.id).following,
          :conversation_id => params[:convo_id],
          :parent_id => nil,
          :published => true
        )
      elsif params[:user_id]
        if (User.find(@user.id).hasAccepted?(params[:user_id]) or @user.id == Integer(params[:user_id]))
          to_send = Slice.where(
            :user_id => params[:user_id],
            :conversation_id => nil,
            :parent_id => nil,
            :published => true
          )
        else
          e = Error.new(:status => 401, :message => "Can't view this user's slices.")
          render :json => e.to_json, :status => 401
          return
        end
      else
        accepted_followers = Relationship.where(:follower_id => @user.id, :accepted => true).pluck(:followed_id)
        to_send = Slice.where(
          :user_id => accepted_followers,
          :conversation_id => nil,
          :parent_id => nil,
          :published => true
        )
        # to_send = Slice.where(:user_id => User.find(@user.id).following, :conversation_id => nil, :parent_id => nil)
      end

      if to_send.present?
        to_send = to_send.sort_by &:created_at

        if params[:count]
          to_send = to_send.last(Integer(params[:count]))
        end

        render :json => to_send.to_json(:methods => [:username, :user_photo_id, :toppings_count, :media_list], except: [:updated_at, :is_private]), :status => 200
      else
        # No Slices were found, send an empty array.
        # Remove this...e = Error.new(:status => 400, :message => "No slices found.")
        render :json => [].to_json, :status => 200
      end

    else
      e = Error.new(:status => 401, :message => "Authtoken has expired. Please get a new token and try again!")
      render :json => e.to_json, :status => 401
    end
  end

  def get_toppings
    if @user && @user.authtoken_expiry > Time.now
      if params[:slice_id]
        to_send = Slice.where(
          :parent_id => params[:slice_id],
          :published => true
        )

        render :json => to_send.to_json(:methods => [:username, :user_photo_id, :toppings_count, :media_list], except: [:updated_at, :is_private]), :status => 200
      else
        e = Error.new(:status => 400, :message => "Missing required parameters.")
        render :json => e.to_json, :status => 400
      end
    else
      e = Error.new(:status => 401, :message => "Authtoken has expired. Please get a new token and try again!")
      render :json => e.to_json, :status => 401
    end
  end

  def get_slice_media_list
    if @user && @user.authtoken_expiry > Time.now
      if params[:slice_id]
        to_send = Media.find(params[:slice_id])

        render :json => to_send.to_json(), :status => 200
      else
        e = Error.new(:status => 400, :message => "Missing required parameters.")
        render :json => e.to_json, :status => 400
      end
    else
      e = Error.new(:status => 401, :message => "Authtoken has expired. Please get a new token and try again!")
      render :json => e.to_json, :status => 401
    end
  end

  def unfollow_user
    if request.post?
      if params[:being_followed_id] && params[:user_following_id]
        if @user
          if @user.authtoken_expiry > Time.now
            being_followed_id = params[:being_followed_id]
            user_following_id = params[:user_following_id]

            if @user.id.to_s == being_followed_id || @user.id.to_s == user_following_id

              if Relationship.where(:follower_id => user_following_id).where(:followed_id => being_followed_id).present?

                User.find(user_following_id).unfollow_with_id(being_followed_id)

                m = Message.new(:status => 200, :message => "User unfollowed.")
                render :json => m.to_json, :status => 200

              else
                e = Error.new(:status => 400, :message => "Could not process the request.")
                render :json => e.to_json, :status => 400
              end

            else
              e = Error.new(:status => 400, :message => "User ID not valid.")
              render :json => e.to_json, :status => 400
            end
          else
            e = Error.new(:status => 401, :message => "Authtoken is invalid or has expired. Kindly refresh the token and try again!")
            render :json => e.to_json, :status => 401
          end
        else
          e = Error.new(:status => 400, :message => "No user record found for this email ID.")
          render :json => e.to_json, :status => 400
        end
      else
        e = Error.new(:status => 400, :message => "Required parameters are missing.")
        render :json => e.to_json, :status => 400
      end
    end
  end

  def follow_user
    if request.post?
      if params[:other_user]
        if @user
          if @user.authtoken_expiry > Time.now
            #this_user_id = params[:user]
            this_user_id = @user.id
            other_user_id = params[:other_user]

            if this_user_id == other_user_id
              e = Error.new(:status => 400, :message => "You cannot follow yourself.")
              render :json => e.to_json, :status => 400

              return
            end

            if User.where(:id => other_user_id).first.present?
              @other_user = User.find(other_user_id)
            else
              e = Error.new(:status => 400, :message => "Cannot follow a user that does not exist.")
              render :json => e.to_json, :status => 400

              return
            end

            if Relationship.where(:follower_id => this_user_id).where(:followed_id => other_user_id).present?
              e = Error.new(:status => 400, :message => "Cannot follow the same user more than once.")
              render :json => e.to_json, :status => 400

              return
            end

            @user.follow(@other_user)

            m = Message.new(:status => 200, :message => "User followed.")
            render :json => m.to_json, :status => 200

          else
            e = Error.new(:status => 401, :message => "Authtoken is invalid or has expired. Kindly refresh the token and try again!")
            render :json => e.to_json, :status => 401
          end
        else
          e = Error.new(:status => 400, :message => "No user record found for this email ID.")
          render :json => e.to_json, :status => 400
        end
      else
        e = Error.new(:status => 400, :message => "Required parameters are missing.")
        render :json => e.to_json, :status => 400
      end
    end
  end

  def accept_follow
    if request.post?
      if  @user && @user.authtoken_expiry > Time.now && params[:other_user]
            other_user_id = params[:other_user]

            rel = Relationship.where(:followed_id => @user.id, :follower_id => params[:other_user], :accepted => false).first

            if rel.present?
              rel.update_attributes(:accepted => true)

              m = Message.new(:status => 200, :message => "Follow request accepted.")
              render :json => m.to_json, :status => 200
            else
              e = Error.new(:status => 400, :message => "Unable to accept the follow request.")
              render :json => e.to_json, :status => 400
            end
      else
        e = Error.new(:status => 400, :message => "Required parameters are missing.")
        render :json => e.to_json, :status => 400
      end
    end
  end

  def decline_follow
    if request.post?
      if  @user && @user.authtoken_expiry > Time.now && params[:other_user]
            other_user = User.find(params[:other_user])

            if other_user.present?
              other_user.unfollow(@user)

              m = Message.new(:status => 200, :message => "Follow request declined.")
              render :json => m.to_json, :status => 200
            else
              e = Error.new(:status => 400, :message => "Unable to decline the follow request.")
              render :json => e.to_json, :status => 400
            end
      else
        e = Error.new(:status => 400, :message => "Required parameters are missing.")
        render :json => e.to_json, :status => 400
      end
    end
  end

  def get_convos
    if @user && @user.authtoken_expiry > Time.now

      user = User.find(@user.id)
      convos = user.conversations

      render :json => convos.to_json(:include => [:participants]), :status => 200
    else
      e = Error.new(:status => 401, :message => "Authtoken has expired. Please get a new token and try again!")
      render :json => e.to_json, :status => 401
    end
  end

  def leave_convo
    if request.post?
      if params[:convo_id]
        if @user
          if @user.authtoken_expiry > Time.now

            part = Participant.where(:user_id => @user.id, :conversation_id => params[:convo_id]).first

            if part.present?
              part.destroy
            end

            # check if that was the last person in the conversation, if so, remove the conversation.
            # TODO: add removal of all slices in coversation
            if !Participant.where(:conversation_id => params[:convo_id]).present?
              Conversation.find(params[:convo_id]).destroy
            end

            m = Message.new(:status => 200, :message => "Left conversation.")
            render :json => m.to_json, :status => 200

          else
            e = Error.new(:status => 401, :message => "Authtoken is invalid or has expired. Kindly refresh the token and try again!")
            render :json => e.to_json, :status => 401
          end
        else
          e = Error.new(:status => 400, :message => "No user record found for this email ID.")
          render :json => e.to_json, :status => 400
        end
      else
        e = Error.new(:status => 400, :message => "Required parameters are missing.")
        render :json => e.to_json, :status => 400
      end
    end
  end

  def change_convo_notifications
    if request.post?
      if params[:convo_id] && params[:rec_notifs]
        if @user
          if @user.authtoken_expiry > Time.now

            part = Participant.where(:user_id => @user.id, :conversation_id => params[:convo_id]).first

            if part.present?
              if params[:rec_notifs] == "1"
                part.update(:receive_notifications => true)
              else
                part.update(:receive_notifications => false)
              end
            end

            m = Message.new(:status => 200, :message => "Left conversation.")
            render :json => m.to_json, :status => 200

          else
            e = Error.new(:status => 401, :message => "Authtoken is invalid or has expired. Kindly refresh the token and try again!")
            render :json => e.to_json, :status => 401
          end
        else
          e = Error.new(:status => 400, :message => "No user record found for this email ID.")
          render :json => e.to_json, :status => 400
        end
      else
        e = Error.new(:status => 400, :message => "Required parameters are missing.")
        render :json => e.to_json, :status => 400
      end
    end
  end

  def create_convo
      if request.post?
        if params[:title] && params[:chatters]
          if @user
            if @user.authtoken_expiry > Time.now

              chatter_ids = eval(params[:chatters])

              convo = Conversation.create(:title => params[:title], :created_by => @user.id)
              Participant.create(:conversation_id => convo.id, :user_id => @user.id)

              chatter_ids.each{ |chatter_id|
                if User.find(@user.id).followers.find(chatter_id).present?
                  Participant.create(:conversation_id => convo.id, :user_id => chatter_id)
                end
              }

              m = Message.new(:status => 200, :message => "Conversation created.")
              render :json => m.to_json, :status => 200

            else
              e = Error.new(:status => 401, :message => "Authtoken is invalid or has expired. Kindly refresh the token and try again!")
              render :json => e.to_json, :status => 401
            end
          else
            e = Error.new(:status => 400, :message => "No user record found for this email ID.")
            render :json => e.to_json, :status => 400
          end
        else
          e = Error.new(:status => 400, :message => "Required parameters are missing.")
          render :json => e.to_json, :status => 400
        end
      end
  end

  def find_user
    if @user && @user.authtoken_expiry > Time.now
      if params[:search_field]
        searchfield = params[:search_field]
        users = User.where(:username => searchfield).first
        if users.present?
          render :json => users.to_json(:only => [:id, :username, :photo_id]), :status => 200
        else
          users = User.where(:email => searchfield).first
          if users.present?
            render :json => users.to_json(:only => [:id, :username, :photo_id]), :status => 200
          else
            m = Message.new(:status => 203, :message => "No user found.")
            render :json => m.to_json, :status => 203
          end
        end
      else
        e = Error.new(:status => 401, :message => "Missing required parameters.")
        render :json => e.to_json, :status => 401
      end
    else
      e = Error.new(:status => 401, :message => "Authtoken has expired. Please get a new token and try again!")
      render :json => e.to_json, :status => 401
    end
  end

  def update_description
    if request.post?
      if @user
        if @user.authtoken_expiry > Time.now
          if params[:new_description]

             User.find(@user.id).update_attributes(:description => params[:new_description])

              m = Message.new(:status => 200, :message => "Description updated.")
              render :json => m.to_json, :status => 200
            else
              e = Error.new(:status => 400, :message => "Required parameters are missing.")
              render :json => e.to_json, :status => 400
            end

        else
          e = Error.new(:status => 401, :message => "Authtoken is invalid or has expired. Kindly refresh the token and try again!")
          render :json => e.to_json, :status => 401
        end
      else
        e = Error.new(:status => 400, :message => "User not valid.")
        render :json => e.to_json, :status => 400
      end
    end
  end

  def request_user_info
    if @user && @user.authtoken_expiry > Time.now
      if params[:requested_id]

        if params[:for_self] == "1"
          id_to_find = @user.id
        else
          id_to_find = params[:requested_id]
        end

        users = User.find(id_to_find)

        if users.present?
          if id_to_find == @user.id
            render :json => users.to_json(:only => [
                                                      :id,
                                                      :username,
                                                      :description,
                                                      :photo_id,
                                                      :email
                                                    ],
                                                    :methods => [
                                                                  :slice_count,
                                                                  :follower_count,
                                                                  :potential_follower_count,
                                                                  :following_count,
                                                                  :is_email_confirmed?
                                                                ]
                                          ),
                                          :status => 200
          else
            render :json => users.to_json(:only => [
                                                      :id,
                                                      :username,
                                                      :description,
                                                      :photo_id
                                                    ],
                                                    :methods => [
                                                                  :slice_count,
                                                                  :follower_count,
                                                                  :potential_follower_count,
                                                                  :following_count
                                                                ]
                                          ),
                                          :status => 200
          end
        else
          m = Message.new(:status => 203, :message => "No user found.")
          render :json => m.to_json, :status => 203
        end
      else
        e = Error.new(:status => 401, :message => "Missing required parameters.")
        render :json => e.to_json, :status => 401
      end
    else
      e = Error.new(:status => 401, :message => "Authtoken has expired. Please get a new token and try again!")
      render :json => e.to_json, :status => 401
    end
  end

  def request_settings_info
    if @user && @user.authtoken_expiry > Time.now

      user_to_load = User.find(@user.id)

      if user_to_load.blank?
        m = Message.new(:status => 203, :message => "Could not load settings.")
        render :json => m.to_json, :status => 203
      else
        settings_info = user_to_load.setting

        if settings_info.blank?
          settings_info = Setting.create(:user_id => @user.id)
        end

        render :json => settings_info.to_json(except: [:updated_at, :created_at]), :status => 200
      end

    else
      e = Error.new(:status => 401, :message => "Authtoken has expired. Please get a new token and try again!")
      render :json => e.to_json, :status => 401
    end
  end

  def update_settings_info
    if request.post?
      if @user
        if @user.authtoken_expiry > Time.now
          if params[:require_acceptance] && params[:allow_featured] && params[:allow_nearby] && params[:notify_on_followed] &&
             params[:notify_on_accepted] && params[:notify_on_accepted] && params[:notify_on_new_topping] &&
             params[:notify_on_convo_activity] && params[:notify_on_unpublished_activity] && params[:notify_on_featured] &&
             params[:notify_on_expire_soon] && params[:receive_notification_alerts]

             User.find(@user.id).setting.update_attributes(:require_acceptance => params[:require_acceptance],
                                                          :allow_featured => params[:allow_featured],
                                                          :allow_nearby => params[:allow_nearby],
                                                          :notify_on_followed => params[:notify_on_followed],
                                                          :notify_on_accepted => params[:notify_on_accepted],
                                                          :notify_on_new_topping => params[:notify_on_new_topping],
                                                          :notify_on_convo_activity => params[:notify_on_convo_activity],
                                                          :notify_on_unpublished_activity => params[:notify_on_unpublished_activity],
                                                          :notify_on_featured => params[:notify_on_featured],
                                                          :notify_on_expire_soon => params[:notify_on_expire_soon],
                                                          :receive_notification_alerts => params[:receive_notification_alerts])

              m = Message.new(:status => 200, :message => "Settings updated.")
              render :json => m.to_json, :status => 200
            else
              e = Error.new(:status => 400, :message => "Required parameters are missing.")
              render :json => e.to_json, :status => 400
            end

        else
          e = Error.new(:status => 401, :message => "Authtoken is invalid or has expired. Kindly refresh the token and try again!")
          render :json => e.to_json, :status => 401
        end
      else
        e = Error.new(:status => 400, :message => "User not valid.")
        render :json => e.to_json, :status => 400
      end
    end
  end

  def request_followers
    if @user && @user.authtoken_expiry > Time.now
      if params[:requested_id]

        id_to_find = params[:requested_id]

        followers = User.find(id_to_find).followers

        users = followers.map do |f|
          f.attributes = {accepted: Relationship.where(:follower_id => f.id, :followed_id => id_to_find).first.accepted,
                          id: f.id,
                          username: f.username,
                          description: f.description,
                          photo_id: f.photo_id,
                          follower_count: f.follower_count,
                          potential_follower_count: f.potential_follower_count,
                          following_count: f.following_count,
                          slice_count: f.slice_count}
        end

        if users.present?
          render :json => users.to_json(), :status => 200
        else
          m = Message.new(:status => 200, :message => "No followers found.")
          render :json => m.to_json, :status => 200
        end
      else
        e = Error.new(:status => 401, :message => "Missing required parameters.")
        render :json => e.to_json, :status => 401
      end
    else
      e = Error.new(:status => 401, :message => "Authtoken has expired. Please get a new token and try again!")
      render :json => e.to_json, :status => 401
    end
  end

  def request_following
    if @user && @user.authtoken_expiry > Time.now
      if params[:requested_id]

        id_to_find = params[:requested_id]

        users = User.find(id_to_find).following

        if users.present?
          render :json => users.to_json(:only => [:id, :username, :description, :photo_id], :methods => [:slice_count,
                                                                                                         :follower_count,
                                                                                                         :potential_follower_count,
                                                                                                         :following_count]), :status => 200
        else
          m = Message.new(:status => 200, :message => "Not following any users.")
          render :json => m.to_json, :status => 200
        end
      else
        e = Error.new(:status => 401, :message => "Missing required parameters.")
        render :json => e.to_json, :status => 401
      end
    else
      e = Error.new(:status => 401, :message => "Authtoken has expired. Please get a new token and try again!")
      render :json => e.to_json, :status => 401
    end
  end

  def new_device_token
    if request.post?
      if params[:token] && params[:type]
        if @user
          if @user.authtoken_expiry > Time.now

            if Device.where(:token => params[:token]).first.present?
              e = Error.new(:status => 401, :message => "Device already registered.")
              render :json => e.to_json, :status => 401
            else
              # Create new device.
              device = Device.create(:user_id => @user.id,
                                   :token => params[:token])

              # Create endpoint on Amazon SNS.
              sns = AWS::SNS::Client.new

              endpoint = sns.create_platform_endpoint(
                platform_application_arn:'arn:aws:sns:us-east-1:064744778154:app/APNS_SANDBOX/slices_MOBILEHUB_853079710',
                token:params[:token],
                attributes: {}
                )

                device.endpoint_arn = endpoint[:endpoint_arn]
                device.save

            # Send a test notification.

            iphone_notification = {
                aps: {alert: "Thanks!",
                      sound: "default",
                      badge: 1},
                extra: {}
            }

            sns_message = {default: "Thanks for registering your device.",
                           APNS_SANDBOX: iphone_notification.to_json,
                           APNS: iphone_notification.to_json}

            message = sns.publish(target_arn: device.endpoint_arn,
                                  message: sns_message.to_json,
                                  message_structure:"json")

                m = Message.new(:status => 200, :message => "Device token accepted.")
                render :json => m.to_json, :status => 200
            end

          else
            e = Error.new(:status => 401, :message => "Authtoken is invalid or has expired. Kindly refresh the token and try again!")
            render :json => e.to_json, :status => 401
          end
        else
          e = Error.new(:status => 400, :message => "No user record found.")
          render :json => e.to_json, :status => 400
        end
      else
        e = Error.new(:status => 400, :message => "Required parameters are missing.")
        render :json => e.to_json, :status => 400
      end
    end
  end

  private

  def check_for_valid_authtoken
    authenticate_or_request_with_http_token do |token, options|
      @user = User.where(:api_authtoken => token).first
    end
  end

  def rand_string(len)
    o =  [('a'..'z'),('A'..'Z')].map{|i| i.to_a}.flatten
    string  =  (0..len).map{ o[rand(o.length)]  }.join

    return string
  end

  def user_params
    params.require(:user).permit(:username, :email, :password, :password_hash, :password_salt, :verification_code,
    :email_verification, :api_authtoken, :authtoken_expiry)
  end

end
