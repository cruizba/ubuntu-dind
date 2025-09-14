#!/bin/bash

# Start docker
start-docker.sh

# Your commands go here
git clone https://github.com/cruizba/ubuntu-dind
cd ubuntu-dind || exit 1
docker build . -t ubuntu-dind-test

docker run --privileged ubuntu-dind-test docker run hello-world