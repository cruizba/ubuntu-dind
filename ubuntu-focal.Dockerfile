FROM ubuntu:20.04

RUN apt update \
    && apt install -y ca-certificates \
    wget curl iptables supervisor \
    && rm -rf /var/lib/apt/list/*

ENV DOCKER_CHANNEL=stable \
	DOCKER_VERSION=26.1.4 \
	DOCKER_COMPOSE_VERSION=v2.27.0 \
	BUILDX_VERSION=v0.14.0 \
	DEBUG=false

# Docker and buildx installation
RUN set -eux; \
	\
	arch="$(uname -m)"; \
	case "$arch" in \
        # amd64
		x86_64) dockerArch='x86_64' ; buildx_arch='linux-amd64' ;; \
        # arm32v6
		armhf) dockerArch='armel' ; buildx_arch='linux-arm-v6' ;; \
        # arm32v7
		armv7) dockerArch='armhf' ; buildx_arch='linux-arm-v7' ;; \
        # arm64v8
		aarch64) dockerArch='aarch64' ; buildx_arch='linux-arm64' ;; \
		*) echo >&2 "error: unsupported architecture ($arch)"; exit 1 ;;\
	esac; \
	\
	if ! wget -O docker.tgz "https://download.docker.com/linux/static/${DOCKER_CHANNEL}/${dockerArch}/docker-${DOCKER_VERSION}.tgz"; then \
		echo >&2 "error: failed to download 'docker-${DOCKER_VERSION}' from '${DOCKER_CHANNEL}' for '${dockerArch}'"; \
		exit 1; \
	fi; \
	\
	tar --extract \
		--file docker.tgz \
		--strip-components 1 \
		--directory /usr/local/bin/ \
	; \
	rm docker.tgz; \
	if ! wget -O docker-buildx "https://github.com/docker/buildx/releases/download/${BUILDX_VERSION}/buildx-${BUILDX_VERSION}.${buildx_arch}"; then \
		echo >&2 "error: failed to download 'buildx-${BUILDX_VERSION}.${buildx_arch}'"; \
		exit 1; \
	fi; \
	mkdir -p /usr/local/lib/docker/cli-plugins; \
	chmod +x docker-buildx; \
	mv docker-buildx /usr/local/lib/docker/cli-plugins/docker-buildx; \
	\
	dockerd --version; \
	docker --version; \
	docker buildx version

COPY modprobe start-docker.sh entrypoint.sh /usr/local/bin/
COPY supervisor/ /etc/supervisor/conf.d/
COPY logger.sh /opt/bash-utils/logger.sh

RUN chmod +x /usr/local/bin/start-docker.sh \
	/usr/local/bin/entrypoint.sh \
	/usr/local/bin/modprobe

VOLUME /var/lib/docker

# Docker compose installation
RUN curl -L "https://github.com/docker/compose/releases/download/${DOCKER_COMPOSE_VERSION}/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose \
	&& chmod +x /usr/local/bin/docker-compose && docker-compose version

# Create a symlink to the docker binary in /usr/local/lib/docker/cli-plugins
# for users which uses 'docker compose' instead of 'docker-compose'
RUN ln -s /usr/local/bin/docker-compose /usr/local/lib/docker/cli-plugins/docker-compose

ENTRYPOINT ["entrypoint.sh"]
CMD ["bash"]
