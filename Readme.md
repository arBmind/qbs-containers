# Docker images for Qbs

These docker images are used to run continuious integrations and local builds with the Qbs build system.

## Options

compilers and standard libraries:
* Clang/libc++
* Clang/libstdc++
* GCC/libstdc++

Qt:
* none (bring your own)
* Qt official builds (using aqtinstall)

## Usage

Use it like Qbs command line.

```bash
docker run -it \
    --mount src="$(pwd)",target=/build,type=bind \
    -w /build \
    arbmind/qbs-gcc:latest \
    build -d /tmp/qbs -p autotest-runner
```

This mounts your current directory to `/build` in the container. Changes the workdir to `/build` and runs qbs with build path `/tmp/qbs` and targets the `autotest-runner`.

## Details

The Dockerfile is multi staged and has different targets for all the variants.
All targets with underscores are meant to be internally only.

Targets:
* clang
* clang-libstdcpp
* clang-libstdcpp-qt
* gcc
* gcc-qt

Note: clang-qt is missing because the Qt Company does not publish binaries built for libc++
