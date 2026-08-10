# This file is auto-generated from the current state of the database.

ActiveRecord::Schema[7.2].define(version: 2026_01_03_000000) do
  create_table "audit_events", force: :cascade do |t|
    t.string "action", null: false
    t.string "target", null: false
    t.string "actor"
    t.integer "team_id"
    t.text "details"
    t.string "user_agent"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["action"], name: "index_audit_events_on_action"
    t.index ["created_at"], name: "index_audit_events_on_created_at"
  end

  create_table "environment_records", id: false, force: :cascade do |t|
    t.string "id", null: false
    t.string "project_name", null: false
    t.integer "project_id"
    t.integer "team_id"
    t.integer "owner_user_id"
    t.string "session_id"
    t.string "provider", null: false
    t.string "provider_resource_id"
    t.string "provider_resource_type"
    t.string "status", null: false
    t.datetime "created_at", null: false
    t.datetime "expires_at", null: false
    t.string "instance_id"
    t.string "public_ip"
    t.string "private_ip"
    t.string "volume_id"
    t.integer "ttl_minutes", null: false
    t.string "compute_tier", default: "small", null: false
    t.string "instance_type"
    t.string "message"
    t.string "region", null: false
    t.integer "volume_size"
    t.string "storage_tier", default: "balanced", null: false
    t.string "volume_type"
    t.text "tags"
    t.text "notes"
    t.string "ssh_key_name"
    t.string "idempotency_key"
    t.string "request_fingerprint"
    t.datetime "updated_at", null: false
    t.index ["id"], name: "index_environment_records_on_id", unique: true
    t.index ["expires_at"], name: "index_environment_records_on_expires_at"
    t.index ["idempotency_key", "provider"], name: "index_environment_records_on_idempotency_and_provider"
    t.index ["provider"], name: "index_environment_records_on_provider"
    t.index ["status"], name: "index_environment_records_on_status"
  end

  create_table "projects", force: :cascade do |t|
    t.integer "team_id", null: false
    t.string "name", null: false
    t.string "slug", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["team_id", "slug"], name: "index_projects_on_team_id_and_slug", unique: true
    t.index ["team_id"], name: "index_projects_on_team_id"
  end

  create_table "teams", force: :cascade do |t|
    t.string "name", null: false
    t.string "slug", null: false
    t.text "settings"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["slug"], name: "index_teams_on_slug", unique: true
  end

  create_table "users", force: :cascade do |t|
    t.integer "team_id", null: false
    t.string "email", null: false
    t.string "role", default: "viewer", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["email"], name: "index_users_on_email", unique: true
    t.index ["team_id"], name: "index_users_on_team_id"
  end

  add_foreign_key "projects", "teams"
  add_foreign_key "users", "teams"
end
