# frozen_string_literal: true

class EnvironmentRecord < ApplicationRecord
  self.primary_key = 'id'

  serialize :tags, coder: JSON

  validates :id, :project_name, :provider, :status, :created_at, :expires_at, :ttl_minutes, :compute_tier, :region,
            presence: true

  def to_environment
    Environment.new(attributes.symbolize_keys.except(:created_at, :updated_at).merge(
                      created_at: created_at,
                      expires_at: expires_at,
                      tags: tags || {}
                    ))
  end

  def self.from_environment(environment)
    new(environment.to_h.except(:provider_label, :instance_type, :volume_type).merge(
          id: environment.id,
          project_name: environment.project_name,
          project_id: environment.project_id,
          team_id: environment.team_id,
          owner_user_id: environment.owner_user_id,
          session_id: environment.session_id,
          provider: environment.provider,
          provider_resource_id: environment.provider_resource_id,
          provider_resource_type: environment.provider_resource_type,
          status: environment.status,
          created_at: environment.created_at,
          expires_at: environment.expires_at,
          ttl_minutes: environment.ttl_minutes,
          compute_tier: environment.compute_tier,
          instance_type: environment.compute_shape,
          storage_tier: environment.storage_tier,
          volume_type: environment.storage_shape,
          idempotency_key: environment.idempotency_key,
          request_fingerprint: environment.request_fingerprint,
          tags: environment.tags || {}
        ))
  end
end
