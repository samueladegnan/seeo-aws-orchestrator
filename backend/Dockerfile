FROM ruby:3.3-slim

# Install dependencies
RUN apt-get update -qq && apt-get install -y \
  build-essential \
  git \
  pkg-config \
  libsqlite3-dev \
  && rm -rf /var/lib/apt/lists/*

WORKDIR /app

# Install gems
COPY Gemfile Gemfile.lock* ./
RUN bundle install --jobs=4 --retry=3

# Copy application code
COPY . .

# Create writable storage directory for SQLite
RUN mkdir -p /app/storage && chown -R seeo:seeo /app/storage

# Non-root user for runtime security
RUN useradd -m seeo && chown -R seeo:seeo /app
USER seeo

EXPOSE 3000

# NOTE: For production, run `bin/rails solid_queue:install:migrations` and
# commit the generated migrations before building this image.
CMD ["sh", "-c", "bundle exec rails db:prepare && bundle exec rails server -b 0.0.0.0"]
