# Build stage
FROM hexpm/elixir:1.16.0-erlang-26.2.1-alpine-3.19.0 AS builder

# Install build dependencies
RUN apk add --no-cache \
    build-base \
    git \
    nodejs \
    npm

WORKDIR /app

# Install hex and rebar
RUN mix local.hex --force && \
    mix local.rebar --force

# Set build environment
ENV MIX_ENV=prod

# Copy mix files and fetch dependencies
COPY mix.exs mix.lock ./
RUN mix deps.get --only prod
RUN mix deps.compile

# Copy assets and build them
COPY assets/package*.json assets/
RUN cd assets && npm install

COPY priv priv
COPY assets assets
COPY lib lib

RUN mix assets.deploy

# Compile application
RUN mix compile

# Build release
RUN mix release

# Runtime stage
FROM alpine:3.19.0 AS runner

# Install runtime dependencies
RUN apk add --no-cache \
    libstdc++ \
    openssl \
    ncurses-libs \
    python3 \
    py3-pip \
    sqlite

# Install Apprise for notifications
RUN pip3 install --break-system-packages apprise

WORKDIR /app

# Create non-root user
RUN addgroup -g 1000 pricarr && \
    adduser -u 1000 -G pricarr -s /bin/sh -D pricarr

# Copy release from builder
COPY --from=builder --chown=pricarr:pricarr /app/_build/prod/rel/pricarr ./

# Create data directory for SQLite database
RUN mkdir -p /app/data && chown pricarr:pricarr /app/data

USER pricarr

ENV HOME=/app
ENV DATABASE_PATH=/app/data/pricarr.db
ENV PHX_SERVER=true

EXPOSE 4000

CMD ["bin/pricarr", "start"]
