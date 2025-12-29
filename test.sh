#!/bin/bash

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Usage information
function usage() {
    echo "Usage: $0 --mode <mode> --use-systemd <true|false> --image-name <image-name>"
    echo ""
    echo "Arguments:"
    echo "  --mode         : privileged or sysbox-runc"
    echo "  --use-systemd  : true or false"
    echo "  --image-name   : Docker image name to test"
    echo ""
    echo "Example:"
    echo "  $0 --mode privileged --use-systemd false --image-name cruizba/ubuntu-dind:latest"
    echo "  $0 --mode sysbox-runc --use-systemd true --image-name cruizba/ubuntu-dind:noble-systemd"
    exit 1
}

# Logging functions
function log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

function log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

function log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

# Cleanup function
function cleanup() {
    local container_name=$1
    log_info "Cleaning up container: $container_name"
    docker rm -f "$container_name" >/dev/null 2>&1 || true
}

# Wait for Docker daemon to be ready inside DinD container
function wait_for_docker() {
    local container_name=$1
    local max_wait=60
    local waited=0

    log_info "Waiting for Docker daemon to be ready inside DinD container..."

    while [ $waited -lt $max_wait ]; do
        if docker exec "$container_name" docker info >/dev/null 2>&1; then
            log_info "Docker daemon is ready!"
            return 0
        fi
        sleep 2
        waited=$((waited + 2))
        if [ $((waited % 10)) -eq 0 ]; then
            log_info "Waited ${waited}s of ${max_wait}s..."
        fi
    done

    log_error "Docker daemon did not become ready within ${max_wait} seconds"
    return 1
}

# Test nginx inside DinD container
function test_nginx() {
    local container_name=$1

    log_info "Pulling nginx image inside DinD container..."
    if ! docker exec "$container_name" docker pull nginx:alpine; then
        log_error "Failed to pull nginx image"
        return 1
    fi

    log_info "Starting nginx container inside DinD..."
    if ! docker exec "$container_name" docker run -d --name test-nginx -p 8080:80 nginx:alpine; then
        log_error "Failed to start nginx container"
        return 1
    fi

    log_info "Waiting for nginx to be ready..."
    sleep 5

    log_info "Testing HTTP connectivity to nginx..."
    local max_attempts=10
    local attempt=0

    while [ $attempt -lt $max_attempts ]; do
        if docker exec "$container_name" curl -f http://localhost:8080 >/dev/null 2>&1; then
            log_info "Successfully connected to nginx via HTTP!"

            # Verify we got the nginx welcome page
            local response=$(docker exec "$container_name" curl -s http://localhost:8080)
            if echo "$response" | grep -q "nginx"; then
                log_info "Received nginx welcome page ✓"
                return 0
            else
                log_warning "Connected but didn't receive expected nginx content"
            fi
        fi
        attempt=$((attempt + 1))
        sleep 2
    done

    log_error "Failed to connect to nginx after $max_attempts attempts"

    # Debug information
    log_info "Docker containers running inside DinD:"
    docker exec "$container_name" docker ps -a

    log_info "Nginx container logs:"
    docker exec "$container_name" docker logs test-nginx || true

    return 1
}

# Main test function
function run_test() {
    local mode=$1
    local use_systemd=$2
    local image_name=$3
    local container_name="dind-test-$$"

    log_info "========================================="
    log_info "Starting DinD Test"
    log_info "========================================="
    log_info "Mode: $mode"
    log_info "Systemd: $use_systemd"
    log_info "Image: $image_name"
    log_info "Container name: $container_name"
    log_info "========================================="

    # Prepare docker run command
    local docker_run_cmd="docker run -d --name $container_name"

    # Add mode-specific flags
    if [ "$mode" = "privileged" ]; then
        docker_run_cmd="$docker_run_cmd --privileged"
    elif [ "$mode" = "sysbox-runc" ]; then
        docker_run_cmd="$docker_run_cmd --runtime=sysbox-runc"
    else
        log_error "Invalid mode: $mode"
        usage
    fi

    # Add image name
    docker_run_cmd="$docker_run_cmd $image_name"

    # For systemd images, we need to keep the container running differently
    if [ "$use_systemd" = "true" ]; then
        log_info "Running systemd-based DinD container..."
    else
        log_info "Running standard DinD container..."
        # For non-systemd images, we need to keep the container alive
        docker_run_cmd="$docker_run_cmd sleep infinity"
    fi

    log_info "Executing: $docker_run_cmd"

    # Start the DinD container
    if ! eval "$docker_run_cmd"; then
        log_error "Failed to start DinD container"
        cleanup "$container_name"
        return 1
    fi

    log_info "DinD container started successfully"

    # For non-systemd images, start Docker manually
    if [ "$use_systemd" = "false" ]; then
        log_info "Starting Docker daemon in non-systemd container..."
        if ! docker exec "$container_name" /usr/local/bin/start-docker.sh; then
            log_error "Failed to start Docker daemon"
            docker logs "$container_name"
            cleanup "$container_name"
            return 1
        fi
    else
        log_info "Systemd will handle Docker daemon startup..."
        # Give systemd time to start Docker
        sleep 5
    fi

    # Wait for Docker to be ready
    if ! wait_for_docker "$container_name"; then
        log_error "Docker daemon is not ready"
        docker logs "$container_name"
        cleanup "$container_name"
        return 1
    fi

    # Run nginx test
    if ! test_nginx "$container_name"; then
        log_error "Nginx test failed"
        cleanup "$container_name"
        return 1
    fi

    # Cleanup
    log_info "Stopping nginx container inside DinD..."
    docker exec "$container_name" docker stop test-nginx >/dev/null 2>&1 || true
    docker exec "$container_name" docker rm test-nginx >/dev/null 2>&1 || true

    cleanup "$container_name"

    log_info "========================================="
    log_info "✓ Test completed successfully!"
    log_info "========================================="

    return 0
}

# Parse arguments
MODE=""
USE_SYSTEMD=""
IMAGE_NAME=""

while [[ $# -gt 0 ]]; do
    case $1 in
        --mode)
            MODE="$2"
            shift 2
            ;;
        --use-systemd)
            USE_SYSTEMD="$2"
            shift 2
            ;;
        --image-name)
            IMAGE_NAME="$2"
            shift 2
            ;;
        *)
            log_error "Unknown option: $1"
            usage
            ;;
    esac
done

# Check if all required arguments are provided
if [ -z "$MODE" ] || [ -z "$USE_SYSTEMD" ] || [ -z "$IMAGE_NAME" ]; then
    log_error "Missing required arguments"
    usage
fi

# Validate mode
if [ "$MODE" != "privileged" ] && [ "$MODE" != "sysbox-runc" ]; then
    log_error "Invalid mode: $MODE (must be 'privileged' or 'sysbox-runc')"
    usage
fi

# Validate use-systemd flag
if [ "$USE_SYSTEMD" != "true" ] && [ "$USE_SYSTEMD" != "false" ]; then
    log_error "Invalid use-systemd flag: $USE_SYSTEMD (must be 'true' or 'false')"
    usage
fi

# Validate image exists
log_info "Checking if image exists: $IMAGE_NAME"
if ! docker image inspect "$IMAGE_NAME" >/dev/null 2>&1; then
    log_warning "Image not found locally. Attempting to pull..."
    if ! docker pull "$IMAGE_NAME"; then
        log_error "Failed to pull image: $IMAGE_NAME"
        exit 1
    fi
fi

# Run the test
if run_test "$MODE" "$USE_SYSTEMD" "$IMAGE_NAME"; then
    exit 0
else
    log_error "Test failed!"
    exit 1
fi
