# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this is

A single `docker-compose.yaml` that runs headless [Throne](https://throneproj.github.io/headless/) (a proxy client) as one service, `throne`. There is no build, lint, or test step; the only artifact is the compose file. Its inline comments are the main documentation, so keep them accurate when you change settings.

## Commands

```sh
docker compose up -d                 # start
docker compose logs throne           # web UI cert fingerprint + first-start password
docker compose config                # validate the compose file after edits

# thronectl must run inside the container, after loading the API connection info:
docker compose exec throne sh -c 'eval "$(/opt/Throne/Throne --print-connection)" && thronectl status'
docker compose exec -T throne sh -c 'eval "$(/opt/Throne/Throne --print-connection)" && thronectl import -' < links.txt
docker compose exec throne thronectl web passwd    # change the web UI password
```

## Configuration model

- **Image**: pulled from a GHCR mirror (`mirror-ghcr.pkg.shecan.ir`) pinned to a release tag, not from `ghcr.io` directly. The upstream `ghcr.io` line is kept commented out as the alternative.
- **Tun mode / kill switch** need `cap_add: NET_ADMIN` and `/dev/net/tun`. A proxy-only setup needs neither. `stop_grace_period: 45s` gives Throne time to stop the core and then the kill switch. Keep it longer than Docker's 10 s default.
- **State** lives in the named volume `throne-data` at `/var/lib/throne`. The API key is at `/var/lib/throne/config/api.key`.
- **Ports**:
  - `2080`: mixed HTTP+SOCKS inbound. Throne binds it to 127.0.0.1 by default, so the mapping only works after `thronectl settings set inbound_address=0.0.0.0`.
  - `9095`: management API (`THRONE_API_LISTEN`).
  - `9096`: HTTPS web UI with a self-signed cert (`THRONE_WEB_LISTEN`).
- **LAN API access**: `THRONE_API_ALLOW` sets the allowed CIDR. Over a port mapping, every request looks external, so management operations (import, settings, backup) also need `THRONE_API_ADMIN_LAN=1`. Without it, the LAN can only monitor and switch profiles.
- **Gateway alternative**: `network_mode: host` (with `ports:` removed) makes Tun and the kill switch act on the whole host. Only one Tun-owning Throne can run per host.
- **Security caveat**: Docker's published ports bypass host firewalls such as ufw. On an internet-reachable host, bind mappings to the LAN address (for example `"192.168.1.2:9096:9096"`), not all interfaces.
