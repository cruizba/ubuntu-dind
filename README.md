[![GitHub Repo stars](https://img.shields.io/github/stars/cruizba/ubuntu-dind)](https://github.com/cruizba/ubuntu-dind)
[![GitHub Release Date](https://img.shields.io/github/release-date/cruizba/ubuntu-dind)](https://github.com/cruizba/ubuntu-dind/releases)

[![X (formerly Twitter) Follow](https://img.shields.io/twitter/follow/cruizba)](https://x.com/cruizba)

# Ubuntu DinD(Docker in Docker) Image

A docker image based in ubuntu to run docker containers inside docker containers with some extras:

1. Easy to use ([More Info](#3-usage-guide)):
> [!WARNING]
> The option `--privileged` is not secure. Just for dev or testing purposes.
> To do this in the GOOD AND SECURE WAY just use: https://github.com/nestybox/sysbox
```
docker run -it --privileged cruizba/ubuntu-dind
```
or with [sysbox](https://github.com/nestybox/sysbox/blob/master/docs/user-guide/install-package.md):
```
docker run -it --runtime=sysbox-runc cruizba/ubuntu-dind
```
2. Compatible with current LTS versions of Ubuntu (`jammy` and `noble`)
3. Support for arm64 and amd64 architectures.
4. Easy to extend, customize and use.
5. Always updated with current buildx, compose and docker versions.

## Table of Contents

1. [Credits](#1-credits)
2. [Understanding DinD and Its Challenges](#2-understanding-dind-and-its-challenges)
   - [Docker-out-of-Docker (DooD) Using Socket Sharing: Challenges](#21-docker-out-of-docker-dood-using-socket-sharing-challenges)
   - [DinD with Docker Daemon Running in the Container: Solution](#22-dind-with-docker-daemon-running-in-the-container-solution)
3. [Usage Guide](#3-usage-guide)
   - [Quickest but insecure way](#31-quickest-but-insecure-way)
   - [Safer and recommended way](#32-safer-and-recommended-way)
4. [Use Cases](#4-use-cases)
   - [Environment to Test Docker Images](#41-environment-to-test-docker-images)
   - [Running Docker Commands Directly](#42-running-docker-commands-directly)
   - [Extensibility (Automating Builds, Tests with Scripts)](#43-extensibility-automating-builds-tests-with-scripts)
5. [Available Images](#5-available-images)
6. [Support what I do](#6-support-what-i-do)

## 1. Credits

This project was inspired by two existing repositories:

1. [DinD](https://github.com/alekslitvinenk/dind) by [alekslitvinenk](https://github.com/alekslitvinenk): This repository served as the foundational idea, offering a lightweight solution. The distinguishing feature of my project is the use of Ubuntu as the base OS for the container and some improvements I made with time.
2. [Docker](https://github.com/docker-library/docker): This repository literally offers a Docker image of Docker.

## 2. Understanding DinD and Its Challenges

On occasion, there is a need to operate Docker containers within other Docker containers often requiring workaround solutions, especially for usage in CI/CD pipelines or software demanding extensive virtualization.

There are two methods to execute DinD:

### 2.1. Docker-out-of-Docker (DooD) Using Socket Sharing: Challenges

This strategy shares the socket from the host system located at `/var/run/docker.sock` utilizing `-v /var/run/docker.sock:/var/run/docker.sock`. Essentially, this technique allows us to spawn containers from the primary container, which is managed by the host system. However, any containers created within these secondary containers actually materialize only on the host system, not within the originating container itself. Two primary challenges often arise with this approach:

- **Networking Challenges**: With the DooD system, when a container is instantiated within another container, the host system manages both containers. Thus, if we run a container from the DooD container which exposes port 3306, for example, this port would be visible to the host but won't be accessible by the container that initiated it.

- **Directory Volumes**: Suppose we plan to operate 'container-1' within 'container-2' and attempt to share a directory from 'container-1' to 'container-2' using volumes. In that case, this won't work. The reason lies in socket sharing - we're actually not sharing directories from the primary container; instead, we're sharing directories from the host machine. Although there are solutions to these challenges, they often tend to be complex and convoluted.

### 2.2. DinD with Docker Daemon Running in the Container: Solution

This method, although less secure (the `--privileged` option bypasses numerous containerization security features), enables the creation of a fresh container with Docker inside whenever required, effectively resolving network and volumes problems. You can now share folders from 'container-1' to 'container-2', created by 'container-1', and expose ports from 'container-2', accessible from 'container-1'.

But there are actually ways to run this container securely. You can use [nestybox/sysbox](https://github.com/nestybox/sysbox) runtime to run this container securely. This runtime is a container runtime that enables Docker-in-Docker (DinD) with enhanced security and performance. It's a great alternative to the `--privileged` option.

You can see how to run this insecurely or securely in the [Usage Guide](#usage-guide) section.

## 3. Usage Guide

Test or use this image is quite simple, and you have two options to do it.

### 3.1 Quickest but insecure way:

To use this Docker-in-Docker image, run the following command:

```bash
docker run -it --privileged cruizba/ubuntu-dind
```

If you want to have a systemd environment, you can also use the `systemd-latest` tag:

```bash
docker run -d --name ubuntu-dind --privileged cruizba/ubuntu-dind:systemd-latest
docker exec -it ubuntu-dind bash
```

### 3.2 Safer and recommended way:

For this option you need to have Sysbox installed in your system. You can see how to install it [here](https://github.com/nestybox/sysbox/blob/master/docs/user-guide/install-package.md) (Package installation works only in debian-based distros sadly).

To use this Docker-in-Docker image in a more secure environment, run the following command:

```bash
docker run -it --runtime=sysbox-runc cruizba/ubuntu-dind
```

If you want to have a systemd environment, you can also use the `systemd-latest` tag:

```bash
docker run -d --name ubuntu-dind --runtime=sysbox-runc cruizba/ubuntu-dind:systemd-latest
docker exec -it ubuntu-dind bash
```

## 4. Use cases

### 4.1. Environment to Test Docker Images

Simply running the image will give you a clean environment to test your Docker images.

- Insecure command:
```bash
docker run -it --privileged cruizba/ubuntu-dind
```
- Secure command:
```bash
docker run -it --runtime=sysbox-runc cruizba/ubuntu-dind
```

This will run a root bash terminal inside the container, where you can run docker commands.

### 4.2. Running Docker Commands Directly

You can run commands directly to test images:

- Insecure command:
```bash
docker run -it --privileged cruizba/ubuntu-dind docker run hello-world
```
- Secure command:
```bash
docker run -it --runtime=sysbox-runc cruizba/ubuntu-dind docker run hello-world
```

### 4.3. Extensibility (Automating Builds, Tests with Scripts)

You can extend this image to add your own tools and configurations. I will create an example where I use this image to build this project and test it, to show you how to extend it and how powerful it can be.

```Dockerfile
FROM cruizba/ubuntu-dind:latest

# Install dependencies
RUN apt-get update && apt-get install git -y

COPY entrypoint.sh /usr/local/bin/
RUN chmod +x /usr/local/bin/entrypoint.sh
```

**entrypoint.sh:**
```bash
#!/bin/bash

# Start docker
start-docker.sh

# Your commands go here
git clone https://github.com/cruizba/ubuntu-dind
cd ubuntu-dind || exit 1
docker build . -f ubuntu-jammy.Dockerfile -t ubuntu-dind-test

docker run --privileged ubuntu-dind-test docker run hello-world
```

This script will clone this repository, build the image and run a container from it.

It is very important to notice that you need to run the `start-docker.sh` script before using docker commands. This script will start the docker daemon inside the container.

You have this example in the `examples` folder.

> [!NOTE]
> With systemd images, the entrypoint script is different and the `start-docker.sh` script is not needed. To execute commands in systemd images, you need to `docker exec` into the container and run the commands.

## 5. Available images

You can find the available images in the [Docker Hub](https://hub.docker.com/r/cruizba/ubuntu-dind).
Check also the Releases section to see the available tags: [Releases](https://github.com/cruizba/ubuntu-dind/releases)

All tags are released in this format:

- **Fixed images**: Images with a fixed version of Docker, Docker Compose and Docker Buildx. You can check each version in the Releases section. If releases of Docker are slow from time to time, revisions will be released to keep the base image updated.
- **Fixed images and revision**: These images are the most stable images. They have a fixed version of Docker, Docker Compose and Docker Buildx and a revision number. Once released, they will not be updated.
- **Latest images per Ubuntu version**: These images are the latest images for each Ubuntu version. They will be updated with the latest versions of Docker, Docker Compose and Docker Buildx.
- **Latest images**: These images are the latest Docker, Docker Compose and Docker Buildx versions for the latest Ubuntu version.

### Fixed images

```bash
# Normal images
cruizba/ubuntu-dind:focal-<docker-version>
cruizba/ubuntu-dind:jammy-<docker-version>
cruizba/ubuntu-dind:noble-<docker-version>

# Systemd images
cruizba/ubuntu-dind:focal-systemd-<docker-version>
cruizba/ubuntu-dind:jammy-systemd-<docker-version>
cruizba/ubuntu-dind:noble-systemd-<docker-version>
```

### Fixed images and revision

```bash
# Normal images
cruizba/ubuntu-dind:focal-<docker-version>-r<revision>
cruizba/ubuntu-dind:jammy-<docker-version>-r<revision>
cruizba/ubuntu-dind:noble-<docker-version>-r<revision>

# Systemd images
cruizba/ubuntu-dind:focal-systemd-<docker-version>-r<revision>
cruizba/ubuntu-dind:jammy-systemd-<docker-version>-r<revision>
cruizba/ubuntu-dind:noble-systemd-<docker-version>-r<revision>
```

### Latest Images per Ubuntu version:

```bash
# Normal images
cruizba/ubuntu-dind:focal-latest
cruizba/ubuntu-dind:jammy-latest
cruizba/ubuntu-dind:noble-latest

# Systemd images
cruizba/ubuntu-dind:focal-systemd-latest
cruizba/ubuntu-dind:jammy-systemd-latest
cruizba/ubuntu-dind:noble-systemd-latest
```

### Latest Images:

```bash
# Normal images
cruizba/ubuntu-dind:latest

# Systemd images
cruizba/ubuntu-dind:systemd-latest
```

## 6. Support what I do

If you like what I do, you can support me as a GitHub Sponsor. I will be very grateful for your support.

[![GitHub Sponsors](https://img.shields.io/badge/Sponsor%20me%20on-GitHub-green?style=for-the-badge&logo=github)](https://github.com/sponsors/cruizba)
