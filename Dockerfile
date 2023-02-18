FROM ubuntu:20.04

RUN apt update \
    && apt install -y ca-certificates openssh-client \
    wget curl iptables supervisor \
    && rm -rf /var/lib/apt/list/* && \
	if [ $(uname -m) = "armv7" ] || [ $(uname -m) = "armv7l" ]; then \
		# For some reason, certificates are incorrectly installed on armv7l
		# So it is necessary to post process the certificates
		# with this command to make it work
		# https://stackoverflow.com/a/70771488
		for i in /etc/ssl/certs/*.pem; do HASH=$(openssl x509 -hash -noout -in $i); ln -s $(basename $i) /etc/ssl/certs/$HASH.0; done; \
	fi

ENV DOCKER_CHANNEL=stable \
	DOCKER_VERSION=20.10.23 \
	DOCKER_COMPOSE_VERSION=v2.16.0 \
	DEBUG=false

# Docker installation
RUN set -eux; \
	\
	arch="$(uname -m)"; \
	case "$arch" in \
        # amd64
		x86_64) dockerArch='x86_64' ;; \
        # arm32v6
		armhf) dockerArch='armel' ;; \
        # arm32v7
		armv7|armv7l) dockerArch='armhf' ;; \
        # arm64v8
		aarch64) dockerArch='aarch64' ;; \
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
	\
	dockerd --version; \
	docker --version

COPY modprobe startup.sh /usr/local/bin/
COPY supervisor/ /etc/supervisor/conf.d/
COPY logger.sh /opt/bash-utils/logger.sh

RUN chmod +x /usr/local/bin/startup.sh /usr/local/bin/modprobe
VOLUME /var/lib/docker

# Docker compose installation
RUN curl -L "https://github.com/docker/compose/releases/download/${DOCKER_COMPOSE_VERSION}/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose \
	&& chmod +x /usr/local/bin/docker-compose && docker-compose version
	
# Create a symlink to the docker binary in /usr/local/lib/docker/cli-plugins
# for users which uses 'docker compose' instead of 'docker-compose'
RUN mkdir -p /usr/local/lib/docker/cli-plugins \
	&& ln -s /usr/local/bin/docker-compose /usr/local/lib/docker/cli-plugins/docker-compose

ENTRYPOINT ["startup.sh"]
CMD ["bash"]
