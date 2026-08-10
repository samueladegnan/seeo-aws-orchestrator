FROM ruby:3.3-slim

# SEEO runs safely in mock mode by default. Real provider mode expects the
# selected adapter runner image to add its cloud CLI and workload identity.

RUN apt-get update -qq && apt-get install -y \
  build-essential \
  git \
  pkg-config \
  libsqlite3-dev \
  jq \
  && rm -rf /var/lib/apt/lists/*

WORKDIR /app

COPY Gemfile Gemfile.lock* ./
RUN bundle install --jobs=4 --retry=3

RUN useradd -m seeo
COPY . .
RUN chown -R seeo:seeo /app
RUN mkdir -p /app/storage && chown -R seeo:seeo /app/storage

USER seeo

EXPOSE 3000

CMD ["sh", "-c", "bundle exec rails db:prepare && bundle exec rails server -b 0.0.0.0"]
