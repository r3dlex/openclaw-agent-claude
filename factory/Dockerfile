FROM elixir:1.17-otp-27-slim AS builder

RUN apt-get update && apt-get install -y --no-install-recommends \
    git \
    ca-certificates \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /app

# Install hex and rebar
RUN mix local.hex --force && mix local.rebar --force

# Cache deps
COPY mix.exs ./
RUN MIX_ENV=prod mix deps.get && MIX_ENV=prod mix deps.compile

# Build release
COPY config config
COPY lib lib
RUN MIX_ENV=prod mix release

# ── Runtime ──
FROM debian:bookworm-slim

RUN apt-get update && apt-get install -y --no-install-recommends \
    libstdc++6 \
    openssl \
    ca-certificates \
    curl \
    git \
    && rm -rf /var/lib/apt/lists/*

# Install Node.js (required for claude CLI)
RUN curl -fsSL https://deb.nodesource.com/setup_24.x | bash - \
    && apt-get install -y --no-install-recommends nodejs \
    && rm -rf /var/lib/apt/lists/*

# Install Claude Code CLI
RUN npm install -g @anthropic-ai/claude-code@latest

WORKDIR /app

COPY --from=builder /app/_build/prod/rel/factory ./

ENV AGENT_DATA_DIR=/data
ENV FACTORY_PORT=4000

EXPOSE 4000

RUN mkdir -p /data/logs /data/sessions /data/memory

ENTRYPOINT ["/app/bin/factory"]
CMD ["start"]
