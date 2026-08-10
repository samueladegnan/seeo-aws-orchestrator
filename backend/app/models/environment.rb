# frozen_string_literal: true

class Environment
  include ActiveModel::Model

  STATUSES = %w[pending provisioning ready expired terminating terminated error].freeze

  attr_accessor :id, :project_name, :status, :created_at, :expires_at,
                :provider, :provider_resource_id, :provider_resource_type,
                :instance_id, :public_ip, :private_ip, :volume_id, :ttl_minutes, :message,
                :compute_tier, :instance_type, :team_id, :project_id, :owner_user_id, :session_id,
                :idempotency_key, :request_fingerprint, :region, :volume_size, :storage_tier, :volume_type,
                :tags, :notes, :ssh_key_name, :reused

  validates :id, :project_name, :status, :created_at, :expires_at, :ttl_minutes, :provider, :region, presence: true
  validates :provider, inclusion: { in: CloudProvider.provider_names }
  validates :compute_tier, inclusion: { in: CloudProvider::TIERS }, allow_nil: true
  validates :storage_tier, inclusion: { in: CloudProvider::STORAGE_TIERS }, allow_nil: true
  validates :volume_size, numericality: { greater_than_or_equal_to: 10, less_than_or_equal_to: 1000 }, allow_nil: true
  validates :status, inclusion: { in: STATUSES }
  validates :ttl_minutes, numericality: { greater_than_or_equal_to: 1 }

  def provider_label
    CloudProvider.definition(provider)[:short_label]
  end

  def compute_shape
    instance_type || CloudProvider.compute_shape(provider, compute_tier || 'small')
  end

  def storage_shape
    volume_type || CloudProvider.storage_shape(provider, storage_tier || 'balanced')
  end

  def initialize(attributes = {})
    super
    @status ||= 'pending'
    @provider ||= 'aws'
    @compute_tier ||= 'small'
    @storage_tier ||= 'balanced'
    @reused = false if @reused.nil?
  end

  def to_h
    {
      id: id,
      project_name: project_name,
      status: status,
      created_at: created_at&.iso8601,
      expires_at: expires_at&.iso8601,
      provider: provider,
      provider_label: provider_label,
      provider_resource_id: provider_resource_id,
      provider_resource_type: provider_resource_type,
      instance_id: instance_id,
      public_ip: public_ip,
      private_ip: private_ip,
      volume_id: volume_id,
      ttl_minutes: ttl_minutes,
      compute_tier: compute_tier,
      instance_type: compute_shape,
      message: message,
      region: region,
      volume_size: volume_size,
      storage_tier: storage_tier,
      volume_type: volume_type,
      tags: tags,
      notes: notes,
      ssh_key_name: ssh_key_name
    }
  end

  def to_summary
    {
      id: id,
      project_name: project_name,
      status: status,
      created_at: created_at&.iso8601,
      expires_at: expires_at&.iso8601,
      instance_id: instance_id,
      public_ip: public_ip,
      ttl_minutes: ttl_minutes,
      provider: provider,
      provider_label: provider_label,
      provider_resource_id: provider_resource_id,
      compute_tier: compute_tier,
      instance_type: compute_shape,
      region: region,
      volume_size: volume_size,
      storage_tier: storage_tier,
      volume_type: storage_shape,
      tags: tags,
      notes: notes,
      cost: estimated_cost
    }
  end

  def estimated_cost
    CostTrackingService.environment_cost(self)
  end

  def expired?
    return false unless expires_at

    expires_at <= Time.current
  end

  def owned_by?(team_id:, session_id:)
    if team_id.present?
      self.team_id.to_s == team_id.to_s
    else
      self.team_id.blank? && self.session_id.to_s == session_id.to_s
    end
  end

  def stream_key
    if team_id.present?
      "team_#{team_id}"
    else
      "session_#{session_id.presence || 'default'}"
    end
  end
end
