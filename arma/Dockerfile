FROM ubuntu:latest

SHELL ["/bin/bash", "-o", "pipefail", "-c"]

WORKDIR /arma3server
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
        # extDB3, 32-bit. Its other 32-bit dependency, libtbbmalloc.so.2, has no i386 build in Ubuntu at all and
        # comes from the runtime Arma ships instead; see arma_library_path in target/docker.rs.
        zlib1g:i386 \
    # Cleanup
    && apt-get clean autoclean \
    && apt-get autoremove -y \
    && rm -rf /var/lib/apt/lists/*
