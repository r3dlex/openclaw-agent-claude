FROM node:24-slim

LABEL maintainer="openclaw-agent-claude"
LABEL description="Zero-install OpenClaw gateway"

RUN apt-get update && apt-get install -y --no-install-recommends \
    git \
    curl \
    jq \
    && rm -rf /var/lib/apt/lists/*

RUN npm install -g openclaw@latest
RUN npm install -g @anthropic-ai/claude-code@latest
RUN openclaw plugins install @betrue/openclaw-claude-code-plugin || true

WORKDIR /workspace

EXPOSE 18789

COPY entrypoint.sh /usr/local/bin/entrypoint.sh
RUN chmod +x /usr/local/bin/entrypoint.sh

ENTRYPOINT ["entrypoint.sh"]
