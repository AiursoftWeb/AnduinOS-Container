#!/usr/bin/env bash
set -euo pipefail

TARGET_ARCH="${1:-}"
UBUNTU_SUITE="${2:-resolute}"
ROOTFS_DIR="${3:-/out/rootfs}"
APKG_SERVER="${4:-https://packages.anduinos.com}"
APKG_CERT_NAME="${5:-anduinos}"
UBUNTU_ARCHIVE_KEYRING_URL="${UBUNTU_ARCHIVE_KEYRING_URL:-https://archive.ubuntu.com/ubuntu/project/ubuntu-archive-keyring.gpg}"

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

DEBOOTSTRAP_SCRIPT="/usr/share/debootstrap/scripts/$UBUNTU_SUITE"
if [[ ! -e "$DEBOOTSTRAP_SCRIPT" ]]; then
    if [[ "$UBUNTU_SUITE" == "resolute" && -e /usr/share/debootstrap/scripts/gutsy ]]; then
        ln -s /usr/share/debootstrap/scripts/gutsy "$DEBOOTSTRAP_SCRIPT"
    else
        echo "Unsupported Ubuntu suite for local debootstrap scripts: $UBUNTU_SUITE" >&2
        exit 1
    fi
fi

WORKDIR="$(mktemp -d)"
trap 'rm -rf "$WORKDIR"' EXIT
UBUNTU_KEYRING="$WORKDIR/ubuntu-archive-keyring.gpg"
curl -fsSL "$UBUNTU_ARCHIVE_KEYRING_URL" > "$UBUNTU_KEYRING"

debootstrap \
    --arch="$TARGET_ARCH" \
    --variant=minbase \
    --keyring="$UBUNTU_KEYRING" \
    --include=ca-certificates,curl,gnupg \
    "$UBUNTU_SUITE" \
    "$ROOTFS_DIR" \
    "$UBUNTU_MIRROR"

mkdir -p "$ROOTFS_DIR/usr/share/keyrings"
install -m 0644 "$UBUNTU_KEYRING" "$ROOTFS_DIR/usr/share/keyrings/ubuntu-archive-keyring.gpg"

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
chroot "$ROOTFS_DIR" env DEBIAN_FRONTEND=noninteractive apt-get -y dist-upgrade
chroot "$ROOTFS_DIR" env DEBIAN_FRONTEND=noninteractive apt-get install -y \
    base-files \
    anduinos-apt-config \
    anduinos-container

chroot "$ROOTFS_DIR" apt-get clean
rm -rf "$ROOTFS_DIR/var/cache/apt/archives/"*
rm -rf "$ROOTFS_DIR/var/lib/apt/lists/"*
