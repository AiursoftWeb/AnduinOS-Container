FROM hub.aiursoft.com/debian:stable-slim AS rootfs-builder

ARG TARGETARCH
ARG UBUNTU_SUITE=resolute
ARG APKG_SERVER=https://packages.anduinos.com
ARG APKG_CERT_NAME=anduinos

RUN apt-get update \
    && apt-get install -y --no-install-recommends \
        ca-certificates \
        curl \
        debootstrap \
        gnupg \
        sed \
    && rm -rf /var/lib/apt/lists/*

COPY scripts/build-rootfs.sh /usr/local/bin/build-rootfs

RUN chmod +x /usr/local/bin/build-rootfs \
    && BUILD_ARCH="${TARGETARCH:-$(dpkg --print-architecture)}" \
    && /usr/local/bin/build-rootfs "${BUILD_ARCH}" "${UBUNTU_SUITE}" /out/rootfs "${APKG_SERVER}" "${APKG_CERT_NAME}"

FROM scratch

ARG TARGETARCH
ARG UBUNTU_SUITE=resolute

LABEL org.opencontainers.image.title="AnduinOS Container" \
      org.opencontainers.image.description="Cloud-native AnduinOS container image bootstrapped with debootstrap." \
      org.opencontainers.image.vendor="AnduinOS Team"

COPY --from=rootfs-builder /out/rootfs/ /

CMD ["/bin/bash"]