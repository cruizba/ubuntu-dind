#!/bin/bash

DOCKER_VERSION="27.2.1"
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

for version in "${!ubuntu_versions[@]}"; do
    build_image "$version" "${ubuntu_versions[$version]}"
done

echo "All images built successfully!"
