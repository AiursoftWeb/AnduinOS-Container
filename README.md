# AnduinOS Container

AnduinOS Container is a cloud-native, multi-architecture image built with **debootstrap** (not `FROM ubuntu`), then packaged as an OCI image.

Current first-release scope is **resolute**.

## What the image contains

The rootfs is bootstrapped from Ubuntu `resolute`, then configured with:

- Ubuntu upstream APT source (`ubuntu.sources`)
- AnduinOS overlay source (`anduinos.sources`, `packages.anduinos.com`)
- `base-files`
- `anduinos-apt-config`
- `anduinos-container`

This keeps the image Docker-native and avoids desktop/systemd/kernel boot stack payload.

## Build flow

Build logic lives in:

- `scripts/build-rootfs.sh` - creates and configures rootfs
- `Dockerfile` - runs rootfs build in a builder stage and publishes a `scratch` final image

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
- `--build-arg UBUNTU_SUITE=resolute`

and pushes to configured registries as a multi-arch manifest tag.
