FROM node:24-slim

LABEL maintainer="OpenClaw Agent <https://github.com/openclaw>"
LABEL description="Zero-install container for running the OpenClaw agent"

# Install system dependencies
RUN apt-get update && apt-get install -y --no-install-recommends \
    git \
    curl \
    ca-certificates \
    trash-cli \
    && rm -rf /var/lib/apt/lists/*

# Install OpenClaw globally
RUN npm install -g openclaw

# Create non-root user
RUN groupadd -r agent && useradd -r -g agent -m -s /bin/bash agent

# Set workspace directory
WORKDIR /workspace

# Copy entrypoint
COPY scripts/entrypoint.sh /usr/local/bin/entrypoint.sh
RUN chmod +x /usr/local/bin/entrypoint.sh

# Runtime configuration via environment
ENV OPENCLAW_WORKSPACE=/workspace
ENV LOG_LEVEL=info
ENV HEARTBEAT_INTERVAL=1800

# Switch to non-root user
USER agent

ENTRYPOINT ["entrypoint.sh"]
