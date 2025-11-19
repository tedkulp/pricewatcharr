# Build stage
FROM hexpm/elixir:1.18-erlang-26.2-debian-bullseye-20251117-slim AS builder

# Install build dependencies
RUN apt-get update && apt-get install -y --no-install-recommends \
    build-essential \
    git \
    nodejs \
    npm \
    && rm -rf /var/lib/apt/lists/*

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
FROM debian:bookworm-slim AS runner

# Install runtime dependencies
RUN apt-get update && apt-get install -y --no-install-recommends \
    libstdc++6 \
    openssl \
    libncurses6 \
    python3 \
    python3-pip \
    sqlite3 \
    tini \
    && rm -rf /var/lib/apt/lists/*

# Install Apprise for notifications
RUN pip3 install --break-system-packages apprise

WORKDIR /app

# Create non-root user
RUN groupadd -g 1000 pricarr && \
    useradd -u 1000 -g pricarr -s /bin/sh -m pricarr

# Copy release from builder
COPY --from=builder --chown=pricarr:pricarr /app/_build/prod/rel/pricarr ./

# Create data directory for SQLite database
RUN mkdir -p /app/data && chown pricarr:pricarr /app/data

USER pricarr

ENV HOME=/app
ENV DATABASE_PATH=/app/data/pricarr.db
ENV PHX_SERVER=true

EXPOSE 4000

ENTRYPOINT ["/usr/bin/tini", "--"]
CMD ["bin/pricarr", "start"]
