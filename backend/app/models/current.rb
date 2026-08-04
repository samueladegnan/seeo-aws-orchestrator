# frozen_string_literal: true

class Current < ActiveSupport::CurrentAttributes
  attribute :user, :team, :role, :session_id, :service_account, :internal_cleanup

  reset do
    self.session_id = 'default'
    self.service_account = false
    self.internal_cleanup = false
  end
end
