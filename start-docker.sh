#!/bin/bash
source /opt/bash-utils/logger.sh

function wait_for_process () {
    local max_time_wait=30
    local process_name="$1"
    local waited_sec=0
    while ! pgrep "$process_name" >/dev/null && ((waited_sec < max_time_wait)); do
        INFO "Process $process_name is not running yet. Retrying in 1 seconds"
        INFO "Waited $waited_sec seconds of $max_time_wait seconds"
        sleep 1
        ((waited_sec=waited_sec+1))
        if ((waited_sec >= max_time_wait)); then
            return 1
        fi
    done
    return 0
}

function wait_for_docker_api () {
    local max_time_wait=30
    local waited_sec=0

    # dockerd may be running but not yet ready to accept API requests.
    # Wait until the Docker API responds successfully to avoid race conditions
    # with subsequent docker commands.
    while ! docker info >/dev/null 2>&1 && ((waited_sec < max_time_wait)); do
        INFO "Docker API is not ready yet. Retrying in 1 seconds"
        INFO "Waited $waited_sec seconds of $max_time_wait seconds"
        sleep 1
        ((waited_sec=waited_sec+1))
        if ((waited_sec >= max_time_wait)); then
            return 1
        fi
    done
    return 0
}

INFO "Starting supervisor"
/usr/bin/supervisord -n >> /dev/null 2>&1 &

INFO "Waiting for docker to be running"
wait_for_process dockerd
if [ $? -ne 0 ]; then
    ERROR "dockerd is not running after max time"
    exit 1
else
    INFO "dockerd is running"
fi

INFO "Waiting for Docker API to become ready"
wait_for_docker_api
if [ $? -ne 0 ]; then
    ERROR "Docker API did not become ready after max time"
    exit 1
else
    INFO "Docker API is ready"
fi
