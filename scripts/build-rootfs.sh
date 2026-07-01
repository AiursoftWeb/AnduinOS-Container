#!/usr/bin/env bash
set -euo pipefail

TARGET_ARCH="${1:-}"
UBUNTU_SUITE="${2:-resolute}"
ROOTFS_DIR="${3:-/out/rootfs}"
APKG_SERVER="${4:-https://packages.anduinos.com}"
APKG_CERT_NAME="${5:-anduinos}"

if [[ -z "$TARGET_ARCH" ]]; then
    echo "TARGET_ARCH is required. Expected: amd64 or arm64." >&2
    exit 1
fi

case "$TARGET_ARCH" in
amd64)
    UBUNTU_MIRROR="http://archive.ubuntu.com/ubuntu"
    ;;
arm64)
    UBUNTU_MIRROR="http://ports.ubuntu.com/ubuntu-ports"
    ;;
*)
    echo "Unsupported TARGET_ARCH: $TARGET_ARCH. Expected: amd64 or arm64." >&2
    exit 1
    ;;
esac

rm -rf "$ROOTFS_DIR"
mkdir -p "$ROOTFS_DIR"

debootstrap \
    --arch="$TARGET_ARCH" \
    --variant=minbase \
    --include=ca-certificates,curl,gnupg \
    "$UBUNTU_SUITE" \
    "$ROOTFS_DIR" \
    "$UBUNTU_MIRROR"

mkdir -p "$ROOTFS_DIR/etc/apt/sources.list.d"
cat > "$ROOTFS_DIR/etc/apt/sources.list.d/ubuntu.sources" <<EOF
Types: deb
URIs: $UBUNTU_MIRROR
Suites: $UBUNTU_SUITE
Components: main restricted universe multiverse
Signed-By: /usr/share/keyrings/ubuntu-archive-keyring.gpg

Types: deb
URIs: $UBUNTU_MIRROR
Suites: $UBUNTU_SUITE-updates
Components: main restricted universe multiverse
Signed-By: /usr/share/keyrings/ubuntu-archive-keyring.gpg

Types: deb
URIs: $UBUNTU_MIRROR
Suites: $UBUNTU_SUITE-backports
Components: main restricted universe multiverse
Signed-By: /usr/share/keyrings/ubuntu-archive-keyring.gpg

Types: deb
URIs: $UBUNTU_MIRROR
Suites: $UBUNTU_SUITE-security
Components: main restricted universe multiverse
Signed-By: /usr/share/keyrings/ubuntu-archive-keyring.gpg
EOF

rm -f "$ROOTFS_DIR/etc/apt/sources.list"

mkdir -p "$ROOTFS_DIR/usr/share/keyrings"
curl -fsSL "$APKG_SERVER/artifacts/certs/$APKG_CERT_NAME" \
    | sed '1s/^\xEF\xBB\xBF//' \
    | gpg --dearmor \
    > "$ROOTFS_DIR/usr/share/keyrings/anduinos-archive-keyring.gpg"

cat > "$ROOTFS_DIR/etc/apt/sources.list.d/anduinos.sources" <<EOF
Types: deb
URIs: $APKG_SERVER/artifacts/anduinos/
Suites: $UBUNTU_SUITE-addon
Components: main
Architectures: $TARGET_ARCH
Signed-By: /usr/share/keyrings/anduinos-archive-keyring.gpg
EOF

chroot "$ROOTFS_DIR" apt-get update
chroot "$ROOTFS_DIR" env DEBIAN_FRONTEND=noninteractive apt-get install -y \
    base-files \
    anduinos-apt-config \
    anduinos-container

chroot "$ROOTFS_DIR" apt-get clean
rm -rf "$ROOTFS_DIR/var/lib/apt/lists/"*
