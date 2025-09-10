#!/bin/bash

# Create a persistent bash history file if it doesn't exist
if [ ! -f ".docker_history" ]; then
    touch .docker_history
fi

# Run an interactive shell in the Docker image, giving access to host devices (for disks),
# mounting the current directory with the same path inside the container to preserve absolute paths
# and make a persistent bash history.
docker run --privileged \
    -v /dev:/dev \
    -v $(pwd):$(pwd) \
    -v $(pwd)/.docker_history:/home/ubuntu/.bash_history \
    -w $(pwd) -h POS-builder --rm -it pos-build:latest
