# Ubuntu DinD(Docker in Docker) Image

## :warning::warning: WARNING :warning::warning:

The option `--privileged` is not secure. I did this image just for little experiments, don't use for production. Just for dev or testing purposes.

To do this in the GOOD AND SECURE WAY just use: https://github.com/nestybox/sysbox


## Credits

I've created this project as a combination of this two repositories:
- The original idea comes from this project and it's a lighter solution: [DinD](https://github.com/alekslitvinenk/dind) by [alekslitvinenk](https://github.com/alekslitvinenk):
The only difference of this project from the one created by @alekslitvinenk, is that my image is a modification with ubuntu as the base OS of the container.
- [Docker](https://github.com/docker-library/docker) (literally a docker image of docker)

## What is DinD and common problems.

Sometimes we need to run docker containers inside other docker containers, with some "tricky" and "hacky" solution for CI/CD pipelines or software that requires a lot of virtualization... 

There are two ways to run DinD:

### 1. DinD with shared socket:
One of the solutions consists on sharing the socket from the host system in `/var/run/docker.sock` with `-v /var/run/docker.sock:/var/run/docker.sock`. Doing that, we're not really using "docker inside docker", we're creating containers from the container, but they're still being running by the host machine. 
This solution results in the following problems:

- Networking problems: If we run a container inside another container, as the containers are running by the host, if we expose, for example, the port 3306, this port will be visible from the host, but not inside the container that launched the second container.
- Directory volumes: If we want to run a container-1 inside a container-2 and share a direcoty from the container-1 to the container-2 with volumes... this will not work. ¿Why? When you run a container sharing the socket, you're not sharing directories from the container, you're sharing directories from the host machine!!. There are some tricks to solve this problems, but are a bit tricky. 

### 2. DinD with a daemon of docker running in the container

This is not the most secure way to run a container, (the `--privileged` option scapes lots of security features of containerization), but by running this image you can have a clean container with docker inside every time you want, and the network and volumes problems dissapears. You now can share folders from container-1 to the container-2 created by the container-1. And you can expose ports from container-2 and have access to this ports from container1.

## Why another DinD?

I've created this repo for two reasons:

1. I want to have ubuntu as the main OS of the image.
2. I want to extend it to create my own dev environments with docker available, getting ride of the common problems sharing sockets.

## How to use it

```
docker run -it --privileged cruizba/ubuntu-dind
```

This will run a bash with a complete docker separated from your host to build, run and push docker images.


