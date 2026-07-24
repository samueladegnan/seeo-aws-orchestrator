# frozen_string_literal: true

class Environment
  include ActiveModel::Model

  STATUSES = %w[pending provisioning ready expired terminating terminated error].freeze

  attr_accessor :id, :project_name, :status, :created_at, :expires_at,
                :instance_id, :public_ip, :private_ip, :volume_id, :ttl_minutes, :message

  validates :id, :project_name, :status, :created_at, :expires_at, :ttl_minutes, presence: true
  validates :status, inclusion: { in: STATUSES }
  validates :ttl_minutes, numericality: { greater_than_or_equal_to: 1 }

  def initialize(attributes = {})
    super
    @status ||= "pending"
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
      message: message
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
      ttl_minutes: ttl_minutes
    }
  end

  def expired?
    return false unless expires_at

    expires_at <= Time.current
  end
end
