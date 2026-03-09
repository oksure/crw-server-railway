# crw-server on Railway (Caddy Bearer Auth)

A ready-to-deploy package that runs [crw-server](https://lib.rs/crates/crw-server) — a lightweight, Firecrawl-compatible Rust web scraper — behind [Caddy](https://caddyserver.com/) on [Railway](https://railway.app).

Caddy sits in front of crw-server and enforces an `Authorization: Bearer <key>` token on every request. Railway handles public TLS termination.

```
Internet → Railway edge (TLS) → Caddy :$PORT (Bearer check) → crw-server :3000 (loopback)
```

---

## Deploy to Railway (Dashboard GUI)

### 1. Create a new Railway project

1. Go to [railway.app](https://railway.app) and click **New Project**.
2. Choose **Deploy from GitHub repo**.
3. Authorise Railway and select **oksure/crw-server-railway** (or your fork).
4. Railway auto-detects the `Dockerfile` and begins building.

### 2. Set environment variables

Open **your service → Variables** and add the following:

| Variable | Required | Example / Notes |
|---|---|---|
| `CRW_API_KEY` | ✅ | Your Bearer secret, e.g. `fc-abc123`. Use Railway's **Generate** button for a random value. |
| `CRW_EXTRACTION__LLM__PROVIDER` | ✅ (for LLM) | `openai` |
| `CRW_EXTRACTION__LLM__API_KEY` | ✅ (for LLM) | Paste your `sk-...` OpenAI key here. |
| `CRW_EXTRACTION__LLM__MODEL` | optional | `gpt-4o` (default if omitted) |
| `CRW_CRAWLER__MAX_CONCURRENCY` | optional | `10` |
| `CRW_CRAWLER__REQUESTS_PER_SECOND` | optional | `10` |

> **`PORT`** is injected automatically by Railway — do **not** set it manually.

### 3. Expose the service

1. Open **your service → Settings → Networking**.
2. Click **Generate Domain** (or attach a custom domain).
3. Railway issues a public `https://….up.railway.app` URL.

### 4. Verify the deployment

```bash
export BASE="https://your-service.up.railway.app"
export KEY="fc-abc123"          # your CRW_API_KEY value

# Health check — no auth required
curl "$BASE/health"

# Should return 401
curl -X POST "$BASE/v1/scrape" -H "Content-Type: application/json" \
     -d '{"url":"https://example.com"}'

# Authenticated scrape — returns markdown
curl -X POST "$BASE/v1/scrape" \
     -H "Authorization: Bearer $KEY" \
     -H "Content-Type: application/json" \
     -d '{"url":"https://example.com","formats":["markdown"]}'

# LLM structured extraction with OpenAI
curl -X POST "$BASE/v1/scrape" \
     -H "Authorization: Bearer $KEY" \
     -H "Content-Type: application/json" \
     -d '{
       "url": "https://news.ycombinator.com",
       "formats": ["json"],
       "jsonSchema": {
         "type": "object",
         "properties": {
           "top_stories": {
             "type": "array",
             "items": { "type": "string" }
           }
         },
         "required": ["top_stories"]
       }
     }'
```

---

## Architecture

```
┌─────────────────────────────────────────────────┐
│                Railway container                │
│                                                 │
│  Caddy :$PORT  ──(Bearer check)──►  crw-server  │
│  (public, TLS  │                   127.0.0.1    │
│   by Railway)  │                   :3000        │
│                │                   (loopback)   │
└─────────────────────────────────────────────────┘
```

- **Caddy** is the only publicly reachable process. It validates the Bearer token before forwarding any request.
- **crw-server** is bound to `127.0.0.1:3000` (loopback). It is unreachable from outside the container.
- `/health` is exempt from auth so Railway's health-check probe works.
- crw-server's own `[auth]` section in `config.default.toml` is intentionally left unconfigured; Caddy is the sole enforcement point.

---

## Using as a Firecrawl drop-in

Replace your Firecrawl base URL and API key:

```python
import requests

BASE    = "https://your-service.up.railway.app"
HEADERS = {"Authorization": "Bearer fc-abc123",
            "Content-Type":  "application/json"}

resp = requests.post(f"{BASE}/v1/scrape",
                     headers=HEADERS,
                     json={"url": "https://example.com",
                           "formats": ["markdown"]})
print(resp.json()["data"]["markdown"])
```

---

## Local development

```bash
# Build and run locally (Caddy on :8080, crw-server on :3000 internally)
docker build -t crw-railway .
docker run --rm \
  -e CRW_API_KEY="dev-secret" \
  -e CRW_EXTRACTION__LLM__PROVIDER="openai" \
  -e CRW_EXTRACTION__LLM__API_KEY="sk-..." \
  -e CRW_EXTRACTION__LLM__MODEL="gpt-4o" \
  -e PORT=8080 \
  -p 8080:8080 \
  crw-railway

curl http://localhost:8080/health
curl -X POST http://localhost:8080/v1/scrape \
     -H "Authorization: Bearer dev-secret" \
     -H "Content-Type: application/json" \
     -d '{"url":"https://example.com"}'
```

---

## File reference

| File | Purpose |
|---|---|
| `Dockerfile` | Multi-stage build: copies `crw-server` binary from `ghcr.io/us/crw:latest`, installs Caddy on `debian:bookworm-slim` |
| `Caddyfile` | Caddy configuration — Bearer auth guard + reverse proxy to `localhost:3000` |
| `start.sh` | Entrypoint — starts crw-server on loopback then hands PID 1 to Caddy |
| `railway.toml` | Railway build/deploy hints (Dockerfile builder, health-check path, restart policy) |

---

## License

This deployment wrapper is released under the MIT License.  
crw-server itself is licensed under [AGPL-3.0](https://github.com/us/crw/blob/main/LICENSE).
