<a name="anduinos-container"></a>
# Aiursoft AnduinOS Container

AnduinOS Container is a cloud-native, multi-architecture image built with **debootstrap** (not `FROM ubuntu`), then packaged as an OCI image.

Current first-release scope is **resolute**.

## Overview

### What is AnduinOS Container?

This repository builds an AnduinOS userspace container from a bootstrapped root filesystem. It is a shell-oriented OCI image, separate from the desktop installer ISO.

## Installation

Install Docker to pull and run the image. Image builds additionally require Buildx for the multi-architecture command below, and access to the configured registry and package sources.

<a name="pull-image"></a>
Default pull:

```bash
sudo docker pull aiursoft/anduinos
```

This resolves to `:latest`.

Recommended for reproducibility:

```bash
sudo docker pull aiursoft/anduinos:resolute
```

The suite tag selects a suite but is still mutable; it does not freeze an immutable image revision.

## Usage

Start a disposable interactive shell:

```bash
docker run --rm -it aiursoft/anduinos:resolute /bin/bash
```

Changes in this disposable container are removed on exit. Mount a deliberate volume if work must persist; this image does not boot a desktop, kernel or systemd stack.

### What the image contains

The rootfs is bootstrapped from Ubuntu `resolute`, then configured with:

- Ubuntu upstream APT source (`ubuntu.sources`)
- AnduinOS overlay source (`anduinos.sources`, `packages.anduinos.com`)
- `base-files`
- `anduinos-apt-config`
- `anduinos-container`

This keeps the image Docker-native and avoids desktop/systemd/kernel boot stack payload.

During build, `debootstrap` only prepares the base rootfs and repository configuration. Package installation and `dist-upgrade` run in the final Docker build stage so Docker provides the runtime mounts needed by maintainer scripts. The rootfs builder clears `resolv.conf` before copy-out, and the final stage then cleans APT caches/lists and clears `machine-id` to avoid cloned identity and builder-environment DNS residue in published images.

### Build flow

Build logic lives in:

- `scripts/build-rootfs.sh` - creates and configures rootfs
- `Dockerfile` - runs rootfs build in a builder stage and publishes a `scratch` final image

Security and trust:

- debootstrap is executed with an explicit Ubuntu archive keyring (`--keyring=...`)
- the keyring is then installed into the rootfs at `/usr/share/keyrings/ubuntu-archive-keyring.gpg`
- APT deb822 source entries use `Signed-By` for both Ubuntu and AnduinOS repositories
- package installation happens in the Docker build stage instead of a manual chroot

## Configuration

| Input | Default and scope |
| --- | --- |
| `UBUNTU_SUITE` | Docker build argument, default `resolute`. |
| `TARGETARCH` | Docker-provided target architecture; the builder accepts `amd64` or `arm64`, otherwise fails. |
| `APKG_SERVER` | Docker build argument, default `https://packages.anduinos.com`. |
| `APKG_CERT_NAME` | Docker build argument, default `anduinos`. |
| `UBUNTU_ARCHIVE_KEYRING_URL` | Script environment override for the Ubuntu archive keyring; defaults to `https://archive.ubuntu.com/ubuntu/project/ubuntu-archive-keyring.gpg`. It is not exposed as a Docker build argument. |
| `DEBIAN_FRONTEND` | Image environment defaults to `noninteractive`. |
| `SUPPORTED_SUITES`, `LATEST_SUITE` | CI suite list and latest-tag selector, described below. |

The rootfs helper takes architecture, suite, output directory, APKG server and certificate name as positional arguments. The Dockerfile supplies them. It creates/replaces the selected rootfs directory and is a build helper, not a safe host inspection command. The bootstrap mirror and final Ubuntu source are declared in [scripts/build-rootfs.sh](scripts/build-rootfs.sh); AnduinOS APT entries use their declared signing key.

## Development

<a name="local-build"></a>
**Local build.**

If your local Docker supports Buildx:

```bash
docker buildx build . \
  --platform linux/amd64,linux/arm64 \
  --build-arg UBUNTU_SUITE=resolute \
  -t your-registry/anduinos:resolute \
  --push
```

Single-arch local test:

```bash
docker build . -t anduinos-container:test
```

<a name="ci-publish"></a>
**CI publication.**

GitLab CI uses `docker buildx build` with:

- `--platform linux/amd64,linux/arm64`
- `--build-arg UBUNTU_SUITE=<suite>`

CI variables:

- `SUPPORTED_SUITES` (space-separated list, default: `resolute`)
- `LATEST_SUITE` (default: `resolute`, must be included in `SUPPORTED_SUITES`)

Tag behavior:

- each suite in `SUPPORTED_SUITES` publishes `aiursoft/anduinos:<suite>`
- `aiursoft/anduinos:latest` points to `LATEST_SUITE`

Replace `your-registry/anduinos:resolute` with a registry tag you are authorized to publish. `--push` publishes an image; the single-architecture `docker build` example keeps the image local. Current CI publishes only from `master`, so a merge-request branch has no native image-validation job. A build completing does not mean a running container has been updated.

## How to contribute

There are many ways to contribute to the project: logging bugs, submitting pull requests, reporting issues, and creating suggestions.

Even if you have push rights on the repository, you should create a personal fork and create feature branches there when you need them. This keeps the main repository clean and your workflow cruft out of sight.

We're also interested in your feedback on the future of this project. You can submit a suggestion or feature request through the issue tracker. To make this process more effective, we're asking that these include more information to help define them more clearly.



## License

Licensed under [GPL-3.0](LICENSE).
