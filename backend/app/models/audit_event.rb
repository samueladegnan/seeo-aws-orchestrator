# frozen_string_literal: true

class AuditEvent < ApplicationRecord
  validates :action, :target, presence: true
  serialize :details, coder: JSON
end
