# docker-throne

Docker Compose setup for running [Throne](https://throneproj.github.io/headless/) without a desktop UI, with its web UI and a mixed HTTP + SOCKS proxy exposed on your LAN.

## Requirements

- Docker with the Compose plugin (`docker compose`)
- A Linux host with `/dev/net/tun`. This is only needed for Tun mode and the kill switch.

## Clone

```sh
git clone https://github.com/hesam-init/docker-throne.git
cd docker-throne
```

## Configure

Copy the example environment file and edit it:

```sh
cp .env.example .env
```

| Variable                 | Default                     | Purpose                                                                                     |
| ------------------------ | --------------------------- | ------------------------------------------------------------------------------------------- |
| `THRONE_REGISTRY`        | `mirror-ghcr.pkg.shecan.ir` | Registry the image is pulled from. Use `ghcr.io` to pull straight from GitHub.              |
| `THRONE_VERSION`         | `1.4.1`                     | Image tag: a release, or `latest`.                                                          |
| `THRONE_INBOUND_ADDRESS` | `0.0.0.0`                   | Listen address of the proxy inbound, applied on every start. Empty keeps Throne's setting. |
| `THRONE_WEB_PASSWORD`    | empty                       | Web UI password. Empty uses the one printed on first start or set with `thronectl web passwd`. |

`.env` is ignored by git. After changing `THRONE_WEB_PASSWORD`, run `make recreate` (`docker compose up -d --force-recreate`), because Compose doesn't recreate the container when only a secret's value changes.

Also check `docker-compose.yaml`:

- **LAN subnet:** set `THRONE_API_ALLOW` to your network (default `192.168.1.0/24`).
- **Exposed ports:** Docker's published ports bypass host firewalls such as ufw. If the host can be reached from the internet, bind each mapping to the LAN address only:

  ```yaml
  ports: ["192.168.1.2:2080:2080", "192.168.1.2:9096:9096"]
  ```

## Run

```sh
docker compose up -d
docker compose logs throne
```

Look in the first-start logs for the web UI password (unless `THRONE_WEB_PASSWORD` is set) and the certificate fingerprint.

The Makefile wraps these commands. Run `make` to list its targets:

```sh
make up            # start
make logs          # follow logs
make status        # thronectl status
make import FILE=links.txt
make lan-inbound   # expose the proxy inbound through port 2080
make ctl CMD="settings get"
make update        # pull the image tag and recreate the container
```

## Usage

| Port   | Service                                                                    |
| ------ | -------------------------------------------------------------------------- |
| `2080` | Mixed HTTP + SOCKS proxy inbound                                           |
| `9096` | Web UI: `https://<host>:9096` (self-signed certificate)                    |
| `9095` | Management API. Not mapped by default; add `"9095:9095"` to use `thronectl` from another machine |

By default, the proxy inbound listens only on `127.0.0.1` inside the container. `THRONE_INBOUND_ADDRESS=0.0.0.0` in `.env` makes it reachable through the port mapping. To set it by hand instead:

```sh
docker compose exec throne sh -c 'eval "$(/opt/Throne/Throne --print-connection)" && thronectl settings set inbound_address=0.0.0.0'
```

### thronectl

Run `thronectl` inside the container after loading the connection info:

```sh
# Status
docker compose exec throne sh -c 'eval "$(/opt/Throne/Throne --print-connection)" && thronectl status'

# Import share links from a file
docker compose exec -T throne sh -c 'eval "$(/opt/Throne/Throne --print-connection)" && thronectl import -' < links.txt

# Change the web UI password (has no effect while THRONE_WEB_PASSWORD is set)
docker compose exec throne thronectl web passwd
```

The API key used by remote `thronectl` clients is stored at `/var/lib/throne/config/api.key` inside the container.

### Gateway mode

To route the whole host through Throne, replace `ports:` with `network_mode: host`. Tun mode and the kill switch then apply to the whole host. Only one Throne instance that owns a Tun interface can run per host.

## Data

All Throne state is stored in the `throne-data` named volume, mounted at `/var/lib/throne`. Running `docker compose down -v` deletes it.

## Upgrade

Change `THRONE_VERSION` in `.env`, then:

```sh
docker compose pull
docker compose up -d
```

See the [Throne headless guide](https://throneproj.github.io/headless/) for full documentation.
