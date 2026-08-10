# frozen_string_literal: true

class CreateEnvironmentState < ActiveRecord::Migration[7.1]
  # This migration defines the complete provider-neutral environment state table.
  # rubocop:disable Metrics/AbcSize, Metrics/MethodLength
  def change
    create_table :environment_records, id: false do |t| # rubocop:disable Metrics/BlockLength -- schema declaration
      t.string :id, null: false # rubocop:disable Rails/DangerousColumnNames -- provider-neutral external identifier
      t.string :project_name, null: false
      t.integer :project_id
      t.integer :team_id
      t.integer :owner_user_id
      t.string :session_id
      t.string :provider, null: false
      t.string :provider_resource_id
      t.string :provider_resource_type
      t.string :status, null: false
      t.datetime :created_at, null: false
      t.datetime :expires_at, null: false
      t.string :instance_id
      t.string :public_ip
      t.string :private_ip
      t.string :volume_id
      t.integer :ttl_minutes, null: false
      t.string :compute_tier, null: false, default: 'small'
      t.string :instance_type
      t.string :message
      t.string :region, null: false
      t.integer :volume_size
      t.string :storage_tier, null: false, default: 'balanced'
      t.string :volume_type
      t.text :tags
      t.text :notes
      t.string :ssh_key_name
      t.string :idempotency_key
      t.string :request_fingerprint
      t.timestamps null: false
    end

    if connection.adapter_name.downcase.include?('postgres')
      reversible do |dir|
        dir.up { execute 'ALTER TABLE environment_records ADD PRIMARY KEY (id)' }
      end
    end
    add_index :environment_records, :id, unique: true
    add_index :environment_records, :provider
    add_index :environment_records, :status
    add_index :environment_records, :expires_at
    add_index :environment_records, %i[idempotency_key provider], unique: true

    # rubocop:enable Metrics/AbcSize, Metrics/MethodLength

    create_table :audit_events do |t|
      t.string :action, null: false
      t.string :target, null: false
      t.string :actor
      t.integer :team_id
      t.text :details
      t.string :user_agent
      t.timestamps null: false
    end

    add_index :audit_events, :action
    add_index :audit_events, :created_at
  end
end
