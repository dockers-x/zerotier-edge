ARG ALPINE_VERSION=3.22

FROM --platform=$BUILDPLATFORM alpine:${ALPINE_VERSION} AS downloader

ARG TARGETARCH
ARG TARGETVARIANT
ARG UPSTREAM_REPO=mokeyish/zerotier-edge
ARG ZEROTIER_EDGE_VERSION

WORKDIR /tmp/zerotier-edge

RUN apk add --no-cache ca-certificates curl tar

RUN set -eux; \
    : "${ZEROTIER_EDGE_VERSION:?ZEROTIER_EDGE_VERSION build arg is required, for example v0.2.5}"; \
    case "${TARGETARCH}/${TARGETVARIANT:-}" in \
      amd64/*) release_target="x86_64-unknown-linux-musl" ;; \
      arm64/*) release_target="aarch64-unknown-linux-musl" ;; \
      *) echo "Unsupported Docker target: ${TARGETARCH}/${TARGETVARIANT:-}" >&2; exit 1 ;; \
    esac; \
    archive="zerotier-edge-${release_target}-${ZEROTIER_EDGE_VERSION}.tar.gz"; \
    base_url="https://github.com/${UPSTREAM_REPO}/releases/download/${ZEROTIER_EDGE_VERSION}"; \
    curl -fsSLO "${base_url}/${archive}"; \
    curl -fsSLO "${base_url}/${archive}-sha256sum.txt"; \
    sha256sum -c "${archive}-sha256sum.txt"; \
    tar -xzf "${archive}"; \
    binary_path="$(find . -type f -name zerotier-edge -print -quit)"; \
    test -n "${binary_path}"; \
    install -m 0755 "${binary_path}" /usr/local/bin/zerotier-edge

FROM alpine:${ALPINE_VERSION}

ARG ZEROTIER_EDGE_VERSION
ARG VERSION
ARG BUILD_TIME
ARG GIT_COMMIT

LABEL org.opencontainers.image.title="zerotier-edge" \
      org.opencontainers.image.description="Docker image for mokeyish/zerotier-edge release binaries" \
      org.opencontainers.image.version="${ZEROTIER_EDGE_VERSION}" \
      org.opencontainers.image.created="${BUILD_TIME}" \
      org.opencontainers.image.revision="${GIT_COMMIT}" \
      org.opencontainers.image.source="https://github.com/mokeyish/zerotier-edge" \
      org.opencontainers.image.licenses="GPL-3.0"

RUN apk add --no-cache ca-certificates \
    && mkdir -p /data

COPY --from=downloader /usr/local/bin/zerotier-edge /usr/local/bin/zerotier-edge

EXPOSE 9394
VOLUME ["/data"]

ENTRYPOINT ["/usr/local/bin/zerotier-edge"]
CMD ["--host", "0.0.0.0", "--port", "9394", "--zt-api", "http://127.0.0.1:9993", "--work-dir", "/data"]
