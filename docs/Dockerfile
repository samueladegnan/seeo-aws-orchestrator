# Local preview of the SEEO GitHub Pages site
FROM ruby:3.3-slim

WORKDIR /srv/jekyll

# Install build tools and git (required by jekyll-remote-theme)
RUN apt-get update && \
    apt-get install -y --no-install-recommends build-essential git && \
    rm -rf /var/lib/apt/lists/*

# Install GitHub Pages gem (includes jekyll-remote-theme and the Cayman theme support)
RUN gem install github-pages webrick

# Copy site source into the image (use a volume mount for live reload during development)
COPY . /srv/jekyll

EXPOSE 4000

CMD ["jekyll", "serve", "--host", "0.0.0.0", "--watch", "--force_polling", "--incremental"]
