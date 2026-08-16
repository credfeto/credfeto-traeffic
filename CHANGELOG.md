# Changelog
All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

<!--
Please ADD ALL Changes to the UNRELEASED SECTION and not a specific release
-->

## [Unreleased]
### Security
- Restricted the monitoring direct port (457) to POST requests only, since VictoriaMetrics has no built-in authentication and the route was previously open to queries and admin operations from anyone able to reach it.
### Added
- docs/ folder with architecture diagram showing repository folder structure
- cctv.markridgwell.com host routing to 192.168.60.180 over self-signed TLS
- keys.markridgwell.com zone pointing at 192.168.150.220:8081 using the wildcard certificate
- dns-05.markridgwell.com host routing to dual-stack backend 192.168.42.105 / 2a02:8010:61d5:42::105
- dns-06.markridgwell.com host routing to backend 192.168.42.106
- IPv6 support for the Docker network (NAT66 via the host's global address) so Traefik and backends can use IPv6
- IPv6 backend addresses (2a02:8010:61d5:42::101-106) restored for dns.markridgwell.com and dns-01..dns-06; IPv6 clients now route to the IPv6 backend via a ClientIP()-matched router, everything else stays on IPv4
- monitoring.markridgwell.com routing to 192.168.150.134:8428, with a dedicated Cloudflare Tunnel origin port (457) alongside the SNI/HTTPS route
- Add active health checks to the DNS routers - RFC 8484 DoH probe for the DNS-over-HTTPS service and the unauthenticated /api/status probe for the Technitium admin console services, so unhealthy DNS servers are automatically taken out of rotation
- Add health checks to photos, homeassistant, home, defi, linux-cache-01/02, dev-cache-01/02, github-api, cctv, keys and monitoring services (issue #37 Tier A/A'), each verified against the actual backend's own source or documented API behaviour
- Added Traefik failover services so IPv6-only DNS routers fall back to the IPv4 backend pool when all IPv6 backends are unhealthy, instead of returning an error
### Fixed
- YAML document start markers added to docker-compose.yml, dynamic_conf.template.yml, and traefik.yml to satisfy ansible-lint
- watchtower missing a restart policy, leaving it stopped after a Docker daemon restart
- api-nuget, funfair-nuget, funfair-prerelease-nuget and dotnet health checks were all silently probing the same default nginx vhost (builds.dotnet.local) instead of their own, since health checks bypass router middleware and the shared :5555 nginx has no default_server; added hostname: to each so they probe their own vhost, and added the missing npm health check the same way
- audiobookshelf-service pointed at port 8080, which is actually Dozzle on that host - Audiobookshelf itself is published on port 13378; also adds a /healthcheck health check now that the port is correct
### Changed
- Re-addressed dns-01..dns-04 backends to 192.168.42.101-104 (was .251-.254) with new dual-stack IPv6 addresses 2a02:8010:61d5:42::101-104
- Pointed pacman-service and flathub-service at nginx's own TLS ports (8889/8777) on linux-cache-01/02 instead of the cache-proxy app on 7777, matching the flathub serversTransport serverName and flathub-header Host to flathub.local, since traffic now goes directly to nginx's TLS vhosts rather than through cache-proxy
### Deprecated
### Removed
- IPv6 backend addresses from dns-01..dns-05 services; backends are IPv4-only for now
### Deployment Changes
<!--
Releases that have at least been deployed to staging, BUT NOT necessarily released to live.  Changes should be moved from [Unreleased] into here as they are merged into the appropriate release branch
-->
## [0.0.0] - Project created