class InitSchema < ActiveRecord::Migration
  def up

    # These are extensions that must be enabled in order to support this database
    enable_extension "plpgsql"

    create_table "blocks", force: true do |t|
      t.integer  "user_id"
      t.integer  "blocked_user_id"
      t.datetime "created_at"
      t.datetime "updated_at"
    end

    create_table "conversations", force: true do |t|
      t.string   "title"
      t.integer  "created_by"
      t.datetime "created_at"
      t.datetime "updated_at"
    end

    create_table "devices", force: true do |t|
      t.integer  "user_id"
      t.string   "token"
      t.string   "endpoint_arn"
      t.datetime "created_at"
      t.datetime "updated_at"
      t.string   "device_type",  default: "apple"
    end

    create_table "ingredients", force: true do |t|
      t.datetime "created_at"
      t.datetime "updated_at"
      t.integer  "recipe_id"
      t.string   "media_url"
      t.boolean  "is_video",        default: false
      t.float    "duration",        default: 0.0
      t.integer  "index_in_recipe"
      t.integer  "filter",          default: 0
    end

    create_table "notifications", force: true do |t|
      t.string   "alert",          default: ""
      t.integer  "badge",          default: 1
      t.string   "sound",          default: "default"
      t.json     "custom_payload"
      t.datetime "created_at"
      t.datetime "updated_at"
    end

    create_table "participants", force: true do |t|
      t.integer  "user_id"
      t.integer  "conversation_id"
      t.boolean  "receive_notifications", default: true
      t.integer  "contributions",         default: 0
      t.datetime "created_at"
      t.datetime "updated_at"
    end

    create_table "photos", force: true do |t|
      t.string   "name"
      t.string   "title"
      t.string   "image_url"
      t.integer  "user_id"
      t.datetime "created_at"
      t.datetime "updated_at"
      t.string   "random_id"
    end

    create_table "recipes", force: true do |t|
      t.datetime "created_at"
      t.datetime "updated_at"
      t.integer  "user_id"
      t.string   "title"
      t.date     "last_edited", default: '2017-01-27'
    end

    create_table "relationships", force: true do |t|
      t.integer  "follower_id"
      t.integer  "followed_id"
      t.datetime "created_at"
      t.datetime "updated_at"
      t.boolean  "accepted",    default: true
    end

    add_index "relationships", ["followed_id"], name: "index_relationships_on_followed_id", using: :btree
    add_index "relationships", ["follower_id", "followed_id"], name: "index_relationships_on_follower_id_and_followed_id", unique: true, using: :btree
    add_index "relationships", ["follower_id"], name: "index_relationships_on_follower_id", using: :btree

    create_table "reports", force: true do |t|
      t.integer  "user_id"
      t.integer  "reported_user_id"
      t.integer  "reported_slice_id"
      t.string   "description"
      t.datetime "created_at"
      t.datetime "updated_at"
    end

    create_table "settings", force: true do |t|
      t.integer  "user_id"
      t.boolean  "require_acceptance",          default: false
      t.boolean  "allow_featured",              default: true
      t.boolean  "allow_nearby",                default: true
      t.boolean  "receive_notification_alerts", default: true
      t.boolean  "notify_on_followed",          default: true
      t.boolean  "notify_on_accepted",          default: true
      t.boolean  "notify_on_new_topping",       default: true
      t.boolean  "notify_on_convo_activity",    default: true
      t.boolean  "notify_on_recipe_activity",   default: true
      t.boolean  "notify_on_featured",          default: true
      t.boolean  "notify_on_expire_soon",       default: true
      t.datetime "created_at"
      t.datetime "updated_at"
    end

    create_table "slices", force: true do |t|
      t.integer  "user_id"
      t.integer  "parent_id"
      t.string   "media_id"
      t.string   "title"
      t.boolean  "is_video",        default: false
      t.boolean  "is_private",      default: false
      t.integer  "views",           default: 0
      t.integer  "reported",        default: 0
      t.datetime "created_at"
      t.datetime "updated_at"
      t.integer  "conversation_id"
      t.string   "location_string", default: ""
      t.float    "latitude",        default: 40.712784
      t.float    "longitude",       default: -74.005941
      t.datetime "expiration",      default: '2017-01-28 20:39:22'
      t.integer  "height",          default: 0
      t.integer  "width",           default: 0
    end

    create_table "users", force: true do |t|
      t.string   "username"
      t.string   "email"
      t.string   "password_hash"
      t.string   "password_salt"
      t.boolean  "email_verification", default: false
      t.string   "verification_code"
      t.string   "api_authtoken"
      t.datetime "authtoken_expiry"
      t.datetime "created_at"
      t.datetime "updated_at"
      t.string   "photo_id"
      t.integer  "views"
      t.boolean  "is_active",          default: true
      t.string   "description",        default: ""
      t.boolean  "verified",           default: false
      t.date     "birthdate",          default: '2017-01-27'
    end

    create_table "videos", force: true do |t|
      t.string   "name"
      t.string   "title"
      t.string   "image_url"
      t.integer  "user_id"
      t.string   "random_id"
      t.datetime "created_at"
      t.datetime "updated_at"
    end

  end

  def down
    raise ActiveRecord::IrreversibleMigration, "The initial migration is not revertable"
  end
end
