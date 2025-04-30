#!/bin/bash
set -e

DOCKER_VERSION="28.1.1"
BUILD_NUMBER="0"
LATEST_UBUNTU_VERSION="24.04"

declare -A ubuntu_versions=(
  ["20.04"]="focal"
  ["22.04"]="jammy"
  ["24.04"]="noble"
)

build_image() {
    local ubuntu_version=$1
    local ubuntu_name=$2

    echo "Building image for Ubuntu ${ubuntu_version} (${ubuntu_name})"

    docker build \
        --build-arg UBUNTU_VERSION=${ubuntu_version} \
        -t cruizba/ubuntu-dind:${ubuntu_name}-${DOCKER_VERSION} \
        -t cruizba/ubuntu-dind:${ubuntu_name}-${DOCKER_VERSION}-r${BUILD_NUMBER} \
        -t cruizba/ubuntu-dind:${ubuntu_name}-latest \
        -f Dockerfile .

    if [ "${ubuntu_version}" == "${LATEST_UBUNTU_VERSION}" ]; then
        docker tag cruizba/ubuntu-dind:${ubuntu_name}-latest cruizba/ubuntu-dind:latest
    fi
}

build_systemd_image() {
    local ubuntu_version=$1
    local ubuntu_name=$2

    echo "Building image for Ubuntu ${ubuntu_version} (${ubuntu_name}) with systemd"

    docker build \
        --build-arg UBUNTU_VERSION=${ubuntu_version} \
        -t cruizba/ubuntu-dind:${ubuntu_name}-systemd-${DOCKER_VERSION} \
        -t cruizba/ubuntu-dind:${ubuntu_name}-systemd-${DOCKER_VERSION}-r${BUILD_NUMBER} \
        -t cruizba/ubuntu-dind:${ubuntu_name}-systemd-latest \
        -f Dockerfile.systemd .

    if [ "${ubuntu_version}" == "${LATEST_UBUNTU_VERSION}" ]; then
        docker tag cruizba/ubuntu-dind:${ubuntu_name}-systemd-latest cruizba/ubuntu-dind:systemd-latest
    fi
}

for version in "${!ubuntu_versions[@]}"; do
    build_image "$version" "${ubuntu_versions[$version]}"
done

for version in "${!ubuntu_versions[@]}"; do
    build_systemd_image "$version" "${ubuntu_versions[$version]}"
done

echo "All images built successfully!"
