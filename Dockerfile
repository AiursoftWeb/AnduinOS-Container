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

FROM scratch AS installed-rootfs

ARG TARGETARCH
ARG UBUNTU_SUITE=resolute

COPY --from=rootfs-builder /out/rootfs/ /

ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update \
    && apt-get -y dist-upgrade \
    && apt-get install -y \
        base-files \
        anduinos-apt-config \
        anduinos-container \
    && apt-get clean \
    && rm -rf /var/cache/apt/archives/* /var/lib/apt/lists/* \
    && rm -f /etc/machine-id /var/lib/dbus/machine-id \
    && touch /etc/machine-id

FROM scratch

LABEL org.opencontainers.image.title="AnduinOS Container" \
      org.opencontainers.image.description="Cloud-native AnduinOS container image bootstrapped with debootstrap." \
      org.opencontainers.image.vendor="AnduinOS Team"

COPY --from=installed-rootfs / /

ENV DEBIAN_FRONTEND=noninteractive

CMD ["/bin/bash"]
