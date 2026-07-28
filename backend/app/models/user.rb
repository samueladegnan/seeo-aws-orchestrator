# frozen_string_literal: true

class User < ApplicationRecord
  belongs_to :team, optional: true

  ROLES = %w[admin operator viewer].freeze

  validates :email, presence: true, uniqueness: { case_sensitive: false }
  validates :role, inclusion: { in: ROLES }

  def admin?
    role == 'admin'
  end

  def operator?
    admin? || role == 'operator'
  end

  def viewer?
    role.in?(%w[admin operator viewer])
  end
end
