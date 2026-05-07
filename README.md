# Traefik Setup

Traefik v2.9 reverse proxy using Let's Encrypt TLS via Cloudflare DNS challenge.

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
```

`.env` is gitignored and will not be committed.

### Environment variables reference

| Variable | Required | Used by | Purpose |
|----------|----------|---------|---------|
| `CLOUDFLARE_EMAIL` | Yes | `traefik` | Used to populate Traefik ACME email (`TRAEFIK_CERTIFICATESRESOLVERS_LETSENCRYPT_ACME_EMAIL`) for Let's Encrypt registration. |
| `CF_DNS_API_TOKEN` | Yes | `traefik` | Cloudflare DNS API token used by the ACME DNS challenge provider. |
| `CLOUDFLARE_TUNNEL_TOKEN` | Yes (if running `cloudflare` service) | `cloudflare` | Token passed to `cloudflared tunnel run --token ...` to establish the Cloudflare Tunnel. |
| `TRAEFIK_CERTIFICATESRESOLVERS_LETSENCRYPT_ACME_EMAIL` | Set by compose | `traefik` container environment | Derived from `${CLOUDFLARE_EMAIL}` in `docker-compose.yml`; no separate `.env` entry is required. |

### 3. Start Traefik

```bash
docker compose up -d
```

## Configuration files

| File | Purpose |
|------|---------|
| `traefik.yml` | Static configuration — entrypoints, ACME, providers |
| `dynamic_conf.yml` | Dynamic configuration — routers, services, middlewares |
| `traefik-acme` (Docker volume) | Let's Encrypt certificate storage |

## Adding a new service

In `dynamic_conf.yml`, add a router, service, and middleware following the existing pattern:

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

Traefik watches `dynamic_conf.yml` for changes and reloads automatically — no restart required.

## DNS services

The following DNS routes are configured in `dynamic_conf.yml`:

| Hostname | Upstream service target |
|----------|-------------------------|
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

## Port Mappings

The following table lists all exposed ports and their purposes:

- **443** (TCP/UDP): HTTPS/Let's Encrypt for web-general entrypoint
- **444** (TCP/UDP): Docker Registry direct port (HTTP)
- **446** (TCP/UDP): Home Service direct port (HTTP)
- **447** (TCP/UDP): DeFi Service direct port (HTTP)
- **448** (TCP): NPM Registry direct port
- **449** (TCP): API NuGet Registry direct port
- **450** (TCP): Hotos/Photos direct port
- **451** (TCP): AUR Repository direct port
- **452** (TCP): Pacman Cache direct port
- **453** (TCP): Flathub Repository direct port
- **454** (TCP): DeFi Service alternate direct port

### Service Access Methods

Each service can be accessed via:

1. **HTTPS with Let's Encrypt** (port 443):
   - `npm.markridgwell.com`
   - `api-nuget.markridgwell.com`
   - `hotos.markridgwell.com`
   - `aur.markridgwell.com`
   - `pacman.markridgwell.com`
   - `flathub.markridgwell.com`
   - `defi.markridgwell.com`

2. **Direct HTTP ports** (bypassing TLS):
   - NPM: port 448
   - API NuGet: port 449
   - Photos: port 450
   - AUR: port 451
   - Pacman: port 452
   - Flathub: port 453
   - DeFi: port 454

Direct ports are intended for internal network access or specialised tools that don't support HTTPS proxying.
