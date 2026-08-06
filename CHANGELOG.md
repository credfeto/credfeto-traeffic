# Changelog
All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

<!--
Please ADD ALL Changes to the UNRELEASED SECTION and not a specific release
-->

## [Unreleased]
### Security
### Added
- docs/ folder with architecture diagram showing repository folder structure
- cctv.markridgwell.com host routing to 192.168.60.180 over self-signed TLS
- keys.markridgwell.com zone pointing at 192.168.150.220:8081 using the wildcard certificate
- dns-05.markridgwell.com host routing to dual-stack backend 192.168.42.105 / 2a02:8010:61d5:42::105
- dns-06.markridgwell.com host routing to backend 192.168.42.106
### Fixed
- YAML document start markers added to docker-compose.yml, dynamic_conf.template.yml, and traefik.yml to satisfy ansible-lint
### Changed
- Re-addressed dns-01..dns-04 backends to 192.168.42.101-104 (was .251-.254) with new dual-stack IPv6 addresses 2a02:8010:61d5:42::101-104
### Deprecated
### Removed
- IPv6 backend addresses from dns-01..dns-05 services; backends are IPv4-only for now
### Deployment Changes
<!--
Releases that have at least been deployed to staging, BUT NOT necessarily released to live.  Changes should be moved from [Unreleased] into here as they are merged into the appropriate release branch
-->
## [0.0.0] - Project created