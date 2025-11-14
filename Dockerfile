ARG UBUNTU_VERSION="24.04"
FROM ubuntu:${UBUNTU_VERSION}

ARG UBUNTU_VERSION
ENV DOCKER_CHANNEL=stable \
    DOCKER_VERSION=29.0.0 \
    DOCKER_COMPOSE_VERSION=v2.40.3 \
    BUILDX_VERSION=v0.29.1 \
    DEBUG=false

# Install common dependencies
RUN set -eux; \
    apt-get update && apt-get install -y \
    ca-certificates wget curl iptables supervisor \
    && rm -rf /var/lib/apt/lists/*

# Set iptables-legacy for Ubuntu 22.04 and newer
RUN set -eux; \
    if [ "${UBUNTU_VERSION}" != "20.04" ]; then \
    update-alternatives --set iptables /usr/sbin/iptables-legacy; \
    fi

# Install Docker
RUN apt-get update && apt-get install -y wget curl \
    && rm -rf /var/lib/apt/lists/* \
    && curl -fsSL https://get.docker.com -o get-docker.sh && sh get-docker.sh --version ${DOCKER_VERSION} \
    && rm get-docker.sh \
    && docker --version

# Install buildx
RUN set -eux; \
    arch="$(uname -m)"; \
    case "$arch" in \
        x86_64) dockerArch='x86_64' ; buildx_arch='linux-amd64' ;; \
        armhf) dockerArch='armel' ; buildx_arch='linux-arm-v6' ;; \
        armv7) dockerArch='armhf' ; buildx_arch='linux-arm-v7' ;; \
        aarch64) dockerArch='aarch64' ; buildx_arch='linux-arm64' ;; \
        *) echo >&2 "error: unsupported architecture ($arch)"; exit 1 ;; \
    esac && \
    wget -O docker-buildx "https://github.com/docker/buildx/releases/download/${BUILDX_VERSION}/buildx-${BUILDX_VERSION}.${buildx_arch}" && \
    mkdir -p /usr/local/lib/docker/cli-plugins && \
    chmod +x docker-buildx && \
    mv docker-buildx /usr/local/lib/docker/cli-plugins/docker-buildx && \
    docker buildx version

COPY modprobe start-docker.sh entrypoint.sh /usr/local/bin/
COPY supervisor/ /etc/supervisor/conf.d/
COPY logger.sh /opt/bash-utils/logger.sh

RUN chmod +x /usr/local/bin/start-docker.sh \
    /usr/local/bin/entrypoint.sh \
    /usr/local/bin/modprobe

VOLUME /var/lib/docker

# Install Docker Compose
RUN set -eux; \
    curl -L "https://github.com/docker/compose/releases/download/${DOCKER_COMPOSE_VERSION}/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose && \
    chmod +x /usr/local/bin/docker-compose && \
    docker-compose version && \
    ln -s /usr/local/bin/docker-compose /usr/local/lib/docker/cli-plugins/docker-compose

# TODO: Remove when this issue is fixed: https://github.com/nestybox/sysbox/issues/973
# Temporarly fix containerd version
RUN set -eux; \
    . /etc/os-release; \
    if [ -z "${VERSION_ID:-}" ] || [ -z "${VERSION_CODENAME:-}" ]; then \
        echo "Unable to detect Ubuntu version metadata"; exit 1; \
    fi; \
    apt-get update; \
    apt-get install -y --allow-downgrades "containerd.io=1.7.28-1~ubuntu.${VERSION_ID}~${VERSION_CODENAME}" && \
    apt-mark hold containerd.io

ENTRYPOINT ["entrypoint.sh"]
CMD ["bash"]
