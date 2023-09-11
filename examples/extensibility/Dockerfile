FROM cruizba/ubuntu-dind:latest

# Install dependencies
RUN apt-get update && apt-get install git -y

COPY entrypoint.sh /usr/local/bin/
RUN chmod +x /usr/local/bin/entrypoint.sh