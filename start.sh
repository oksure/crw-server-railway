#!/bin/sh
# start.sh — launches crw-server (background) then Caddy (foreground / PID 1).
# If Caddy exits for any reason, the trap kills crw-server so Docker/Railway
# sees a non-zero exit and automatically restarts the container.
set -eu

# ── crw-server ────────────────────────────────────────────────────────────────
# Bind to loopback only; public traffic must come through Caddy.
CRW_SERVER__HOST=127.0.0.1 \
CRW_SERVER__PORT=3000 \
crw-server &

CRW_PID=$!
echo "[start] crw-server started (pid $CRW_PID)"

# Kill crw-server whenever this script exits (clean shutdown or crash).
trap 'echo "[start] stopping crw-server"; kill "$CRW_PID" 2>/dev/null' EXIT INT TERM

# Give crw-server a moment to bind before Caddy starts forwarding.
sleep 1

# ── Caddy (becomes PID 1 via exec) ───────────────────────────────────────────
exec caddy run --config /etc/caddy/Caddyfile --adapter caddyfile
