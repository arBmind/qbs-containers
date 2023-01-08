# Docker images for Qbs

This project builds Docker images around the Qbs build system used for CI runs.

| Image (latest versions) | Size |
| -- | -- |
| [![Docker Image Version (latest semver)](https://img.shields.io/docker/v/arbmind/qbs-clang?color=black&label=arbmind%2Fqbs-clang&logo=Docker&sort=semver)](https://hub.docker.com/r/arbmind/qbs-clang) | [![Docker Image Size (latest semver)](https://img.shields.io/docker/image-size/arbmind/qbs-clang?color=green&logo=Ubuntu&sort=semver)](https://hub.docker.com/r/arbmind/qbs-clang) |
| [![Docker Image Version (latest semver)](https://img.shields.io/docker/v/arbmind/qbs-clang-libstdcpp?color=black&label=arbmind%2Fqbs-clang-libstdcpp&logo=Docker&sort=semver)](https://hub.docker.com/r/arbmind/qbs-clang-libstdcpp) | [![Docker Image Size (latest semver)](https://img.shields.io/docker/image-size/arbmind/qbs-clang-libstdcpp?color=green&logo=Ubuntu&sort=semver)](https://hub.docker.com/r/arbmind/qbs-clang-libstdcpp) |
| [![Docker Image Version (latest semver)](https://img.shields.io/docker/v/arbmind/qbs-clang-libstdcpp-qt?color=black&label=arbmind%2Fqbs-clang-libstdcpp-qt&logo=Docker&sort=semver)](https://hub.docker.com/r/arbmind/qbs-clang-libstdcpp-qt) | [![Docker Image Size (latest semver)](https://img.shields.io/docker/image-size/arbmind/qbs-clang-libstdcpp-qt?color=yellow&logo=Ubuntu&sort=semver)](https://hub.docker.com/r/arbmind/qbs-clang-libstdcpp-qt) |
| [![Docker Image Version (latest semver)](https://img.shields.io/docker/v/arbmind/qbs-gcc?color=black&label=arbmind%2Fqbs-gcc&logo=Docker&sort=semver)](https://hub.docker.com/r/arbmind/qbs-gcc) | [![Docker Image Size (latest semver)](https://img.shields.io/docker/image-size/arbmind/qbs-gcc?color=yellow&logo=Ubuntu&sort=semver)](https://hub.docker.com/r/arbmind/qbs-gcc) |
| [![Docker Image Version (latest semver)](https://img.shields.io/docker/v/arbmind/qbs-gcc-qt?color=black&label=arbmind%2Fqbs-gcc-qt&logo=Docker&sort=semver)](https://hub.docker.com/r/arbmind/qbs-gcc-qt) | [![Docker Image Size (latest semver)](https://img.shields.io/docker/image-size/arbmind/qbs-gcc-qt?color=brown&logo=Ubuntu&sort=semver)](https://hub.docker.com/r/arbmind/qbs-gcc-qt) |

## Versions

The compiler and Qt versions, modules and packages are provided as build args.

See links to Dockerhub for older versions listed in tags.
See [`.github/workflows/docker_build.yml`](https://github.com/arBmind/qbs-containers/blob/develop/.github/workflows/docker_build.yml) for the current bulid matrix.

## Basic Usage

The default entry point is the qbs command.

```bash
docker run -it \
    --mount src="$(pwd)",target=/project,type=bind \
    -w /project \
    arbmind/qbs-gcc:latest \
    build -d /tmp/qbs -p autotest-runner
```

This mounts your current directory to `/project` in the container. Changes the workdir to `/project` and runs qbs with build path `/tmp/qbs` and targets the `autotest-runner`.

If you want to run an interactive shell simply add the `--entrypoint /bin/bash` option.


## Details

The Dockerfile is multi staged and has different targets for all the variants.
All targets with underscores are meant to be internally only.

Note: clang libc++ Qt combination is missing because the Qt Company does not publish binaries built for libc++.
