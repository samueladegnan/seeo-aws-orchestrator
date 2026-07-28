# frozen_string_literal: true

class Current < ActiveSupport::CurrentAttributes
  attribute :user, :team, :role, :session_id

  reset do
    self.session_id = 'default'
  end
end
