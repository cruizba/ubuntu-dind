#!/bin/bash

# Start docker
start-docker.sh

# debug
mount |sort || true

# Execute specified command
"$@"
