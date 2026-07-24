# frozen_string_literal: true

# This configuration file will be evaluated by Puma. The top-level methods will
# be injected into Puma's configuration DSL.

max_threads_count = ENV.fetch("RAILS_MAX_THREADS", 5).to_i
min_threads_count = ENV.fetch("RAILS_MIN_THREADS", max_threads_count).to_i
threads min_threads_count, max_threads_count

# Specifies the `port` that Puma will listen on to receive requests; default is 3000.
port ENV.fetch("PORT", 3000)

# Specifies the `environment` Puma will run in.
environment ENV.fetch("RAILS_ENV", "development")

# Specifies the number of `workers` to run in production.
# Workers are not supported in development/test environments.
workers ENV.fetch("WEB_CONCURRENCY", 0).to_i if ENV.fetch("RAILS_ENV", "development") == "production"

# Use the `preload_app!` method when specifying a `workers` number.
preload_app!

# Allow puma to be restarted by `bin/rails restart` command.
plugin :tmp_restart
