# zerotier-edge Docker image

Docker image for [mokeyish/zerotier-edge](https://github.com/mokeyish/zerotier-edge)
release binaries.

This image only runs `zerotier-edge`. It does not install or start
`zerotier-one`. The intended deployment is:

```text
browser -> zerotier-edge container -> host zerotier-one API
```

The host keeps running its existing `zerotier-one` service and owns the real
ZeroTier node identity, network traffic, and controller API.

## Images

The GitHub Actions workflow publishes to:

```text
docker.io/czyt/zerotier-edge
ghcr.io/dockers-x/zerotier-edge
```

For an upstream release such as `v0.2.5`, the workflow publishes these tags:

- `v0.2.5`
- `0.2.5`
- `0.2`
- `0`
- `latest`

Supported platforms:

- `linux/amd64`
- `linux/arm64`

The Dockerfile downloads the matching upstream Linux musl archive and verifies
the upstream `sha256sum.txt` file before copying the binary into the runtime
image. It does not clone or compile the upstream source code.

## How It Works With zerotier-one

`zerotier-one` should already be running on the host:

```sh
sudo systemctl status zerotier-one
```

`zerotier-edge` talks to the host ZeroTier local API:

```text
http://127.0.0.1:9993
```

The Compose file uses `network_mode: host`, so `127.0.0.1:9993` from inside the
container points at the host network namespace. This is important because
ZeroTier's local API commonly listens on localhost only.

The host ZeroTier API token is mounted read-only into the container:

```text
/var/lib/zerotier-one/authtoken.secret -> /data/authtoken.secret
```

`zerotier-edge` uses `/data` as its own work directory. That directory is a
Docker named volume, so the Web UI's own state is persistent and separate from
the host ZeroTier node data.

## Docker Compose

Start the Web UI:

```sh
docker compose up -d
```

Open:

```text
http://<host-ip>:9394
```

Login token:

```sh
sudo cat /var/lib/zerotier-one/authtoken.secret
```

The included `docker-compose.yml` is:

```yaml
services:
  zerotier-edge:
    image: ghcr.io/dockers-x/zerotier-edge:latest
    container_name: zerotier-edge
    restart: unless-stopped
    network_mode: host
    volumes:
      - zerotier-edge-data:/data
      - /var/lib/zerotier-one/authtoken.secret:/data/authtoken.secret:ro
    command:
      - --host
      - 0.0.0.0
      - --port
      - "9394"
      - --zt-api
      - http://127.0.0.1:9993
      - --work-dir
      - /data

volumes:
  zerotier-edge-data:
    name: zerotier-edge-data
```

With `network_mode: host`, do not add a `ports:` block. The Web UI listens
directly on host port `9394`.

## docker run

```sh
docker run -d \
  --name zerotier-edge \
  --restart unless-stopped \
  --network host \
  -v zerotier-edge-data:/data \
  -v /var/lib/zerotier-one/authtoken.secret:/data/authtoken.secret:ro \
  ghcr.io/dockers-x/zerotier-edge:latest \
  --host 0.0.0.0 \
  --port 9394 \
  --zt-api http://127.0.0.1:9993 \
  --work-dir /data
```

## Persistence

There are two separate persistence areas:

| Path | Owner | Purpose |
| --- | --- | --- |
| `/var/lib/zerotier-one` on host | host `zerotier-one` | ZeroTier node identity, controller state, host API token |
| `zerotier-edge-data` Docker volume | `zerotier-edge` container | zerotier-edge work directory and extension state |

Do not use the same directory for both. Keeping `/data` separate avoids mixing
Web UI state with the host ZeroTier node's own files.

Back up the edge volume:

```sh
docker run --rm \
  -v zerotier-edge-data:/data \
  -v "$PWD":/backup \
  alpine tar czf /backup/zerotier-edge-data.tar.gz -C /data .
```

Back up the host ZeroTier identity separately:

```sh
sudo tar czf zerotier-one-data.tar.gz -C /var/lib/zerotier-one .
```

The host `identity.secret` is sensitive. If it is lost, the host ZeroTier node
ID changes and joined networks may need reauthorization.

## Notes

- Do not run another `zerotier-one` inside this container when the host already
  has ZeroTier running. That would create a second node identity and can conflict
  on port `9993`.
- This container does not need `NET_ADMIN`, `/dev/net/tun`, or `9993/udp`,
  because it is not a ZeroTier node. The host `zerotier-one` handles node
  networking.
- If the host ZeroTier data directory differs, change the
  `/var/lib/zerotier-one/authtoken.secret` bind mount.
- If port `9394` is already used, change `--port`.

## Publishing New Versions

The workflow `.github/workflows/docker-image.yml` runs:

- on pushes to `main`
- on pushes to `v*` tags
- every 6 hours to check the upstream latest release
- manually through `workflow_dispatch`

Scheduled runs query the latest release of `mokeyish/zerotier-edge`. If both
Docker Hub and GHCR already have that release tag, the build is skipped.

To publish the latest upstream release manually:

```text
GitHub -> Actions -> Docker Build and Push -> Run workflow
```

Leave `tag` empty to use the upstream latest release.

To publish a specific upstream release manually, fill `tag` with a value such as:

```text
v0.2.5
```

To publish by pushing a Git tag in this repository:

```sh
git tag v0.2.5
git push origin v0.2.5
```

That tag is used as the upstream `zerotier-edge` release version, so only create
tags that exist in `mokeyish/zerotier-edge` releases.

Docker Hub publishing requires these repository secrets:

```text
DOCKERHUB_USERNAME
DOCKERHUB_TOKEN
```
