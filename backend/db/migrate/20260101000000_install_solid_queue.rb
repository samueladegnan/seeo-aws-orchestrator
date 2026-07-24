# frozen_string_literal: true

# Solid Queue tables must be installed before using recurring tasks.
# Run the following command to generate them, then run db:migrate:
#
#   bin/rails solid_queue:install:migrations
#   bin/rails db:migrate
#
class InstallSolidQueue < ActiveRecord::Migration[7.1]
  def change
    # Placeholder migration. Solid Queue install generator provides the real tables.
  end
end
