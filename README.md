# zerotier-edge Docker image

Docker image for [mokeyish/zerotier-edge](https://github.com/mokeyish/zerotier-edge)
release binaries.

This image only runs `zerotier-edge`. It does not start `zerotier-one`, because
the intended deployment is to use an existing ZeroTier service on the host.

The image is published to:

```text
ghcr.io/dockers-x/zerotier-edge
```

## Tags

For an upstream release such as `v0.2.5`, the workflow publishes:

- `v0.2.5`
- `0.2.5`
- `latest`

## Supported platforms

- `linux/amd64`
- `linux/arm64`

The Dockerfile downloads the matching upstream Linux musl archive and verifies
the upstream `sha256sum.txt` file before copying the binary into the runtime
image. It does not clone or compile the upstream source code.

## Docker Compose

This repository includes a Compose file for the common case where ZeroTier is
already running on the host:

```sh
docker compose up -d
```

Then open:

```text
http://<host-ip>:9394
```

The login token is the host ZeroTier API token:

```sh
sudo cat /var/lib/zerotier-one/authtoken.secret
```

The Compose file uses `network_mode: host` so `zerotier-edge` can reach the
host `zerotier-one` local API at `127.0.0.1:9993`. It bind-mounts
`/var/lib/zerotier-one` so the UI can reuse the host token, controller state,
and zerotier-edge extension config.

## docker run

```sh
docker run -d \
  --name zerotier-edge \
  --restart unless-stopped \
  --network host \
  -v /var/lib/zerotier-one:/var/lib/zerotier-one \
  ghcr.io/dockers-x/zerotier-edge:latest \
  --host 0.0.0.0 \
  --port 9394 \
  --zt-api http://127.0.0.1:9993 \
  --work-dir /var/lib/zerotier-one
```

With `network_mode: host`, do not add a `ports:` block. The Web UI listens
directly on the host port `9394`.

## Notes

- Do not run another `zerotier-one` inside this container when the host already
  has ZeroTier running. That would create a second node identity and likely
  conflict on port `9993`.
- Mounting `/var/lib/zerotier-one` lets the UI read the host ZeroTier token and
  controller files.
- If the host ZeroTier data directory differs, change both the volume source and
  `--work-dir`.
- If port `9394` is already used, change `--port`.

## Automation

`.github/workflows/docker-image.yml` runs:

- on pushes to `main`
- on pushes to `v*` tags
- every 6 hours to check the upstream latest release
- manually through `workflow_dispatch`

Scheduled runs skip the build when the current upstream release image tag already
exists in GHCR.

To manually build a specific upstream version, run the workflow with a tag such
as `v0.2.5`.
