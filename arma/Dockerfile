FROM ubuntu:latest

SHELL ["/bin/bash", "-o", "pipefail", "-c"]

WORKDIR /arma3server
VOLUME /steamcmd
STOPSIGNAL SIGINT
EXPOSE 2302/udp 2303/udp 2304/udp 2305/udp 2306/udp

RUN apt-get update \
    && apt-get install software-properties-common -yqq \
    && add-apt-repository multiverse \
    && dpkg --add-architecture i386 \
    && apt-get update \
    && apt-get install -yqq --no-install-recommends --no-install-suggests \
        lib32stdc++6 \
        lib32gcc-s1 \
        libcurl4 \
        libssl-dev \
        openssl \
        curl \
        wget \
        ca-certificates \
        vim \
        procps \
        unzip \
        build-essential \
        pkg-config \
        # Arma3server requires ifconfig
        net-tools \
        # Mikeros
        liblzo2-2 \
        libvorbis0a \
        libvorbisfile3 \
        libvorbisenc2 \
        libogg0 \
        libuchardet0 \
        # extDB3
        libtbb-dev \
        # x32
        gcc-multilib \
        g++-multilib \
        zlib1g:i386 \
        libssl-dev:i386 \
        libc6-dev-i386 \
    # Cleanup
    && apt-get remove --purge -y \
    && apt-get clean autoclean \
    && apt-get autoremove -y \
    && rm -rf /var/lib/apt/lists/*

# Rust
RUN curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y

ENV PATH="/root/.cargo/bin:${PATH}"
ENV LD_LIBRARY_PATH="${LD_LIBRARY_PATH}:/tmp/esm/linux/lib"

# Install PBO library
RUN rustup update  \
    && rustup target add i686-unknown-linux-gnu \
    && rustup toolchain install stable-i686-unknown-linux-gnu --force-non-host \
    && cargo install armake2

# SteamCMD
RUN mkdir -p /steamcmd \
    && wget -qO- 'https://steamcdn-a.akamaihd.net/client/installer/steamcmd_linux.tar.gz' | tar zxf - -C /steamcmd
