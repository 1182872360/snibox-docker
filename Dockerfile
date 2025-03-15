# Stage 1: Build dependencies
FROM ruby:2.6.1-alpine3.9 AS builder

# Configure Alpine mirrors
RUN sed -i 's/dl-cdn.alpinelinux.org/mirrors.aliyun.com/g' /etc/apk/repositories

RUN apk add --no-cache -t build-dependencies \
    build-base \
    postgresql-dev \
    shared-mime-info \
    python2 \
    make \
    g++ \
    && apk add --no-cache \
    git \
    nodejs \
    yarn \
    tzdata \
    openssl

WORKDIR /app

# Install dependencies
COPY Gemfile Gemfile.lock ./
RUN gem install bundler -v 2.3.26 && \
    gem install nokogiri -v 1.10.3 && \
    gem install rake -v 12.3.2 && \
    gem install mimemagic -v 0.3.10 && \
    bundle config --local without 'development test' && \
    bundle install

# Install yarn packages
COPY package.json yarn.lock ./
ENV PYTHON=/usr/bin/python2
RUN yarn config set network-timeout 300000 && \
    yarn config set registry https://registry.npmmirror.com && \
    yarn install --production --frozen-lockfile

# Copy application code
COPY . ./

# Precompile assets
ENV RAILS_ENV=production \
    NODE_ENV=production
RUN SECRET_KEY_BASE=dummy bundle exec rake assets:precompile

# Stage 2: Runtime
FROM ruby:2.6.1-alpine3.9

# Configure Alpine mirrors
RUN sed -i 's/dl-cdn.alpinelinux.org/mirrors.aliyun.com/g' /etc/apk/repositories

RUN apk add --no-cache \
    postgresql-libs \
    nodejs \
    tzdata \
    openssl

WORKDIR /app

# Copy built artifacts from builder
COPY --from=builder /app /app
COPY --from=builder /usr/local/bundle /usr/local/bundle


# Add healthcheck
HEALTHCHECK --interval=30s --timeout=5s --start-period=60s \
  CMD curl -f http://localhost:3000/health || exit 1

# Expose port
EXPOSE 3000

# Start the application
CMD ["sh", "-c", "SECRET_KEY_BASE=$(openssl rand -hex 64) bundle exec puma -C config/puma.rb"]
