# frozen_string_literal: true

class Environment
  include ActiveModel::Model

  STATUSES = %w[pending provisioning ready expired terminating terminated error].freeze

  attr_accessor :id, :project_name, :status, :created_at, :expires_at,
                :instance_id, :public_ip, :private_ip, :volume_id, :ttl_minutes, :message,
                :instance_type, :session_id, :region, :volume_size, :volume_type,
                :tags, :notes, :ssh_key_name

  validates :id, :project_name, :status, :created_at, :expires_at, :ttl_minutes, :region, presence: true
  validates :volume_size, numericality: { greater_than_or_equal_to: 10, less_than_or_equal_to: 1000 }, allow_nil: true
  validates :status, inclusion: { in: STATUSES }
  validates :ttl_minutes, numericality: { greater_than_or_equal_to: 1 }

  def initialize(attributes = {})
    super
    @status ||= 'pending'
  end

  def to_h
    {
      id: id,
      project_name: project_name,
      status: status,
      created_at: created_at&.iso8601,
      expires_at: expires_at&.iso8601,
      instance_id: instance_id,
      public_ip: public_ip,
      private_ip: private_ip,
      volume_id: volume_id,
      ttl_minutes: ttl_minutes,
      instance_type: instance_type,
      message: message,
      region: region,
      volume_size: volume_size,
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
      instance_type: instance_type,
      region: region,
      volume_size: volume_size,
      volume_type: volume_type,
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
end
