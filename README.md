# AnduinOS Container

AnduinOS Container is a cloud-native, multi-architecture image built with **debootstrap** (not `FROM ubuntu`), then packaged as an OCI image.

Current first-release scope is **resolute**.

## Pull image

Default pull:

```bash
sudo docker pull aiursoft/anduinos
```

This resolves to `:latest`.

Recommended for reproducibility:

```bash
sudo docker pull aiursoft/anduinos:resolute
```

## What the image contains

The rootfs is bootstrapped from Ubuntu `resolute`, then configured with:

- Ubuntu upstream APT source (`ubuntu.sources`)
- AnduinOS overlay source (`anduinos.sources`, `packages.anduinos.com`)
- `base-files`
- `anduinos-apt-config`
- `anduinos-container`

This keeps the image Docker-native and avoids desktop/systemd/kernel boot stack payload.

During build, `debootstrap` only prepares the base rootfs and repository configuration. Package installation and `dist-upgrade` run in the final Docker build stage so Docker provides the runtime mounts needed by maintainer scripts. The rootfs builder clears `resolv.conf` before copy-out, and the final stage then cleans APT caches/lists and clears `machine-id` to avoid cloned identity and builder-environment DNS residue in published images.

## Build flow

Build logic lives in:

- `scripts/build-rootfs.sh` - creates and configures rootfs
- `Dockerfile` - runs rootfs build in a builder stage and publishes a `scratch` final image

Security and trust:

- debootstrap is executed with an explicit Ubuntu archive keyring (`--keyring=...`)
- the keyring is then installed into the rootfs at `/usr/share/keyrings/ubuntu-archive-keyring.gpg`
- APT deb822 source entries use `Signed-By` for both Ubuntu and AnduinOS repositories
- package installation happens in the Docker build stage instead of a manual chroot

Architecture handling:

- `amd64` uses `http://archive.ubuntu.com/ubuntu`
- `arm64` uses `http://ports.ubuntu.com/ubuntu-ports`

## Local build

If your local Docker supports Buildx:

```bash
docker buildx build . \
  --platform linux/amd64,linux/arm64 \
  --build-arg UBUNTU_SUITE=resolute \
  -t <your-tag> \
  --push
```

Single-arch local test:

```bash
docker build . -t anduinos-container:test
```

## CI publish

GitLab CI uses `docker buildx build` with:

- `--platform linux/amd64,linux/arm64`
- `--build-arg UBUNTU_SUITE=<suite>`

CI variables:

- `SUPPORTED_SUITES` (space-separated list, default: `resolute`)
- `LATEST_SUITE` (default: `resolute`, must be included in `SUPPORTED_SUITES`)

Tag behavior:

- each suite in `SUPPORTED_SUITES` publishes `aiursoft/anduinos:<suite>`
- `aiursoft/anduinos:latest` points to `LATEST_SUITE`
