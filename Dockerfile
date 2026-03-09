# ── Stage 1: pull the pre-built crw-server binary ────────────────────────────
FROM ghcr.io/us/crw:latest AS crw

# ── Stage 2: Debian slim + Caddy + crw-server ─────────────────────────────────
# Must use a glibc-based image; crw-server is compiled against glibc (bookworm).
# caddy:2-alpine is musl-based and would cause the binary to segfault.
FROM debian:bookworm-slim

# Install Caddy from the official Cloudsmith repository
RUN apt-get update \
 && apt-get install -y --no-install-recommends ca-certificates curl gnupg \
 && curl -1sLf 'https://dl.cloudsmith.io/public/caddy/stable/gpg.key' \
      | gpg --dearmor -o /usr/share/keyrings/caddy-stable-archive-keyring.gpg \
 && curl -1sLf 'https://dl.cloudsmith.io/public/caddy/stable/debian.deb.txt' \
      | tee /etc/apt/sources.list.d/caddy-stable.list \
 && apt-get update \
 && apt-get install -y --no-install-recommends caddy \
 && rm -rf /var/lib/apt/lists/*

# Copy crw-server artifacts from stage 1
COPY --from=crw /usr/local/bin/crw-server /usr/local/bin/crw-server
COPY --from=crw /app/config.default.toml  /app/config.default.toml

# Copy runtime configuration
COPY Caddyfile /etc/caddy/Caddyfile
COPY start.sh  /start.sh
RUN chmod +x /start.sh

WORKDIR /app

# Railway injects $PORT at runtime; Caddy binds to it.
# crw-server is internal-only on 127.0.0.1:3000 and is never directly exposed.
CMD ["/start.sh"]
