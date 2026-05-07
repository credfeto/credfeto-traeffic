# Traefik Setup

Traefik v3 reverse proxy using Let's Encrypt TLS via Cloudflare DNS challenge.

## Prerequisites

- Docker and Docker Compose installed
- A Cloudflare account managing your domain's DNS
- A Cloudflare API token with **Zone → DNS → Edit** permission scoped to your domain

## First-time setup

### 1. Create the ACME volume

Traefik stores Let's Encrypt certificates in a named Docker volume that must be created before starting:

```bash
docker volume create traefik-acme
```

### 2. Create the `.env` file

Copy the example and fill in your credentials:

```bash
cp .env.example .env
```

Edit `.env`:

```env
CLOUDFLARE_EMAIL=your@email.com
CF_DNS_API_TOKEN=your_cloudflare_api_token
CLOUDFLARE_TUNNEL_TOKEN=your_cloudflare_tunnel_token
PHOTOS_LOCAL_SECRET=your_photos_shared_secret
```

`.env` is gitignored and will not be committed.

### Environment variables reference

| Variable | Required | Used by | Purpose |
| -------- | -------- | ------- | ------- |
| `CLOUDFLARE_EMAIL` | Yes | `traefik` | Used to populate Traefik ACME email (`TRAEFIK_CERTIFICATESRESOLVERS_LETSENCRYPT_ACME_EMAIL`) for Let's Encrypt registration. |
| `CF_DNS_API_TOKEN` | Yes | `traefik` | Cloudflare DNS API token used by the ACME DNS challenge provider. |
| `CLOUDFLARE_TUNNEL_TOKEN` | Yes (if running `cloudflare` service) | `cloudflare` | Token passed to `cloudflared tunnel run --token ...` to establish the Cloudflare Tunnel. |
| `PHOTOS_LOCAL_SECRET` | Yes | `config-gen` | Shared secret injected into the photos router rule. Requests to port 450 must include `X-Local: <value>` matching this secret; others receive 401. Configure Cloudflare Tunnel to add this header on all requests to the photos origin. |
| `TRAEFIK_CERTIFICATESRESOLVERS_LETSENCRYPT_ACME_EMAIL` | Set by compose | `traefik` container environment | Derived from `${CLOUDFLARE_EMAIL}` in `docker-compose.yml`; no separate `.env` entry is required. |

### 3. Start Traefik

```bash
./update
```

The `update` script validates `.env`, generates `dynamic_conf.yml` from the template, sets up volumes and firewall rules, pulls images, and starts the containers.

## Configuration files

| File | Purpose |
| ---- | ------- |
| `traefik.yml` | Static configuration — entrypoints, ACME, providers |
| `dynamic_conf.yml.template` | Dynamic configuration template — routers, services, middlewares; committed to git |
| `dynamic_conf.yml` | Generated from template by `./update`; gitignored, never committed |
| `traefik-acme` (Docker volume) | Let's Encrypt certificate storage |

## Adding a new service

In `dynamic_conf.yml.template`, add a router, service, and middleware following the existing pattern:

```yaml
http:
  routers:
    my-router:
      rule: "Host(`my-service.markridgwell.com`)"
      service: my-service
      entryPoints:
        - web-secure
      tls:
        certResolver: letsencrypt
      middlewares:
        - my-header

  services:
    my-service:
      loadBalancer:
        servers:
          - url: "https://192.168.10.10:5555"
          - url: "https://192.168.10.20:5555"

  middlewares:
    my-header:
      headers:
        customRequestHeaders:
          Host: "my-service.local"
```

Traefik watches `dynamic_conf.yml` for changes and reloads automatically — no restart required for route or service changes. To apply template changes that alter `${PHOTOS_LOCAL_SECRET}` or other substituted values, re-run `./update`.

## DNS services

The following DNS routes are configured in `dynamic_conf.yml.template`:

| Hostname | Upstream service target |
| -------- | ----------------------- |
| `dns.markridgwell.com` | `https://192.168.42.251`, `https://192.168.42.252`, `https://192.168.42.253`, `https://192.168.42.254` |
| `dns-01.markridgwell.com` | `http://192.168.42.251:3000` |
| `dns-02.markridgwell.com` | `http://192.168.42.252:3000` |
| `dns-03.markridgwell.com` | `http://192.168.42.253:3000` |
| `dns-04.markridgwell.com` | `http://192.168.42.254:3000` |

### TLS and Host behavior for `dns.markridgwell.com`

- Upstream TLS uses a dedicated `serversTransports.dns` transport.
- `insecureSkipVerify: true` is enabled to allow self-signed backend certificates.
- `serverName: "dns.markridgwell.com"` is set so SNI matches the backend certificate name.
- Middleware `dns-header` sets `Host: dns.markridgwell.com` on forwarded requests.

The `dns-01` to `dns-04` routes forward to HTTP backends on port `3000` and each has a host-specific header middleware.

## Dashboard

The Traefik dashboard is available at `https://proxy.markridgwell.com` once running.

## Services

All services are accessible via HTTPS on port 443 with Let's Encrypt certificates unless stated otherwise.

### Development Cache Services

- `dev-cache-01.markridgwell.com` → `http://192.168.150.100:8080`
- `dev-cache-02.markridgwell.com` → `http://192.168.150.101:8080`
- `linux-cache-01.markridgwell.com` → `http://192.168.150.200:8080`
- `linux-cache-02.markridgwell.com` → `http://192.168.150.201:8080`

### Docker Services

- `docker-registry.markridgwell.com` → `http://192.168.150.202:8080` — also available on port **444** (HTTP direct)
- `docker-cache.markridgwell.com` → `http://192.168.150.202:8081`

### Git / Workflow Services

- `github-api.markridgwell.com` → `http://192.168.150.15:3000`
- `git-workflow.markridgwell.com` → `https://192.168.150.15:8081`

### Home Automation

- `home.markridgwell.com` → `http://192.168.150.150:8080` — also available on port **446** (HTTP direct)
- `homeassistant.markridgwell.com` → `http://192.168.34.8:8123`
- `audiobookshelf.markridgwell.com` → `http://192.168.150.16:8080`
- `defi.markridgwell.com` → `https://192.168.150.12` — also available on port **447** (HTTP direct)

### Media

- `photos.markridgwell.com` → `http://192.168.150.154:2283` — also available on port **450** (HTTP direct, X-Local header required)

#### Photos — X-Local header authentication (port 450)

Port 450 is the Cloudflare Tunnel origin for `photos.markridgwell.com`. To prevent direct access that bypasses Cloudflare, Traefik validates a shared-secret header on all requests arriving on this port:

- Requests with `X-Local: <PHOTOS_LOCAL_SECRET>` are forwarded to the Immich backend.
- All other requests receive Traefik's default 404 (no matching router).

**Configuration:** Set `PHOTOS_LOCAL_SECRET` in `.env`, then configure the Cloudflare Tunnel origin rule for `photos.markridgwell.com` to add the request header `X-Local: <same value>`. The Cloudflare dashboard path is: **Zero Trust → Networks → Tunnels → [your tunnel] → Public Hostnames → photos.markridgwell.com → Additional application settings → HTTP Settings → Request headers**.

### NuGet Registries

- `api-nuget.markridgwell.com` → `https://192.168.150.100:5555`, `https://192.168.150.101:5555` — also available on port **449** (HTTP direct)
- `funfair-nuget.markridgwell.com` → `https://192.168.150.100:5555`, `https://192.168.150.101:5555` — also available on port **455** (HTTP direct)
- `funfair-prerelease-nuget.markridgwell.com` → `https://192.168.150.100:5555`, `https://192.168.150.101:5555` — also available on port **456** (HTTP direct)

### NPM Registry

- `npm.markridgwell.com` → `https://192.168.150.100:5555`, `https://192.168.150.101:5555` — also available on port **448** (HTTP direct)

### .NET Build Artefacts

- `dotnet.markridgwell.com` → `https://192.168.150.100:5555`, `https://192.168.150.101:5555`

### AI Services

- `ollama.markridgwell.com` → `https://192.168.150.10:5555`, `https://192.168.150.20:5555`

### Linux Package Mirrors

- `aur.markridgwell.com` → `https://192.168.150.200:7776`, `https://192.168.150.201:7776` — also available on port **451** (HTTP direct)
- `aur-repo.markridgwell.com` → `https://192.168.150.10:5555`, `https://192.168.150.20:5555`
- `pacman.markridgwell.com` → `https://192.168.150.200:7777`, `https://192.168.150.201:7777` — also available on port **452** (HTTP direct)
- `flathub.markridgwell.com` → `https://192.168.150.200:7777`, `https://192.168.150.201:7777` — also available on port **453** (HTTP direct)

## Port Mappings

The following table lists all exposed ports and their purposes:

- **443** (TCP/UDP): HTTPS entrypoint — all services with Let's Encrypt TLS + HTTP/3

The ports below are plain HTTP used as Cloudflare Tunnel origin services.
**Each hostname must have its own dedicated port** — Cloudflare Tunnel ingress rules
route by hostname, and each rule maps to a single origin URL (including port).

- **444** (TCP): Docker Registry — HTTP (Cloudflare Tunnel origin)
- **446** (TCP): Home Service — HTTP (Cloudflare Tunnel origin)
- **447** (TCP): DeFi Service — HTTP (Cloudflare Tunnel origin)
- **448** (TCP): NPM Registry — HTTP (Cloudflare Tunnel origin)
- **449** (TCP): API NuGet Registry — HTTP (Cloudflare Tunnel origin)
- **450** (TCP): Photos service — HTTP (Cloudflare Tunnel origin)
- **451** (TCP): AUR Repository — HTTP (Cloudflare Tunnel origin)
- **452** (TCP): Pacman Cache — HTTP (Cloudflare Tunnel origin)
- **453** (TCP): Flathub Repository — HTTP (Cloudflare Tunnel origin)
- **455** (TCP): FunFair NuGet Registry — HTTP (Cloudflare Tunnel origin)
- **456** (TCP): FunFair Pre-release NuGet Registry — HTTP (Cloudflare Tunnel origin)

TLS is terminated by Cloudflare on the public side. Traefik does not re-encrypt
the internal leg from `cloudflared` to itself.
