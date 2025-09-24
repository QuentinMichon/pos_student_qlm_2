# Create a Docker image with every tools required to build and deploy
#
# Copyright (c) 2025 REDS Institute, HEIG-VD
#
# Image build:
# $ docker build -t pos-build .
#
# Running the image in interative mode (allowing to run builds and deploys commands)
# $ docker run --privileged -v /dev:/dev -v $(pwd):$(pwd) -w $(pwd) --rm -it pos-build:latest

# Stage to download and extract toolchains
FROM ubuntu:24.04 AS toolchains-utils
RUN apt-get update && apt-get install -y xz-utils wget \
	&& rm -rf /var/lib/apt/lists/*

# Download and extract toolchains, one stage per toolchain to allow parallel downloads and caching
FROM toolchains-utils AS aarch64-none-linux-gnu
RUN wget -O /tmp/aarch64-none-linux-gnu.tar.xz "https://developer.arm.com/-/media/Files/downloads/gnu/12.2.rel1/binrel/arm-gnu-toolchain-12.2.rel1-$(uname -m)-aarch64-none-linux-gnu.tar.xz"
RUN mkdir /tmp/aarch64-none-linux-gnu
RUN tar xf /tmp/aarch64-none-linux-gnu.tar.xz -C /tmp/aarch64-none-linux-gnu


FROM toolchains-utils AS aarch64-none-elf
RUN wget -O /tmp/aarch64-none-elf.tar.xz "https://developer.arm.com/-/media/Files/downloads/gnu/12.2.rel1/binrel/arm-gnu-toolchain-12.2.rel1-$(uname -m)-aarch64-none-elf.tar.xz"
RUN mkdir /tmp/aarch64-none-elf
RUN tar xf /tmp/aarch64-none-elf.tar.xz -C /tmp/aarch64-none-elf

FROM toolchains-utils AS arm-linux-gnueabihf
RUN wget -O /tmp/arm-linux-gnueabihf.tar.xz "https://snapshots.linaro.org/gnu-toolchain/11.3-2022.06-1/arm-linux-gnueabihf/gcc-linaro-11.3.1-2022.06-$(uname -m)_arm-linux-gnueabihf.tar.xz"
RUN mkdir /tmp/arm-linux-gnueabihf
RUN tar xf /tmp/arm-linux-gnueabihf.tar.xz -C /tmp/arm-linux-gnueabihf

# Final stage: create the build image
FROM ubuntu:24.04

# Change used locale to UTF-8
RUN apt-get update && apt-get install -y locales && rm -rf /var/lib/apt/lists/* \
	&& localedef -i en_US -c -f UTF-8 -A /usr/share/locale/locale.alias en_US.UTF-8
ENV LANG=en_US.utf8

# Install require dependencies and tools
RUN apt-get update && apt-get install -y sudo python3 git file wget xz-utils python3-pip \
	build-essential ninja-build pkg-config libglib2.0-dev libsdl2-dev fdisk \
	cpio unzip rsync bc bzip2 python3-venv \
	make cmake gcc-arm-none-eabi libc-dev \
	bison flex bash patch mount device-tree-compiler \
	dosfstools u-boot-tools net-tools \
	bridge-utils iptables dnsmasq libssl-dev \
	util-linux e2fsprogs vim nano libncurses-dev \
	iputils-ping libpixman-1-dev libxcb-xkb-dev \
	meson lsof picocom ninja-build \
	&& rm -rf /var/lib/apt/lists/*

# Make sudo usable without password
RUN usermod -aG sudo ubuntu
RUN echo '%sudo ALL=(ALL) NOPASSWD:ALL' >> /etc/sudoers

# Copy extracted toolchains
RUN mkdir -p /opt/toolchains/
COPY --from=aarch64-none-linux-gnu /tmp/aarch64-none-linux-gnu/* /opt/toolchains/aarch64-none-linux-gnu
COPY --from=aarch64-none-elf /tmp/aarch64-none-elf/* /opt/toolchains/aarch64-none-elf
COPY --from=arm-linux-gnueabihf /tmp/arm-linux-gnueabihf/* /opt/toolchains/arm-linux-gnueabihf
ENV PATH="$PATH:/opt/toolchains/aarch64-none-linux-gnu/bin/:/opt/toolchains/aarch64-none-elf/bin/:/opt/toolchains/arm-linux-gnueabihf/bin/"

# Improve the shell experience
ENV TERM=xterm-256color
ENV PROMPT_DIRTRIM=3

# Set default user to ubuntu to not create files as root
USER ubuntu
WORKDIR /home/ubuntu/src
