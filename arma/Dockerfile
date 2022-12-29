FROM debian:bullseye-slim

SHELL ["/bin/bash", "-o", "pipefail", "-c"]

RUN apt-get update \
    && apt-get install -yqq --no-install-recommends --no-install-suggests \
        lib32stdc++6 \
        lib32gcc-s1 \
        libcurl4 \
        wget \
        ca-certificates \
        vim \
        # Mikeros
        liblzo2-2 \
        libvorbis0a \
        libvorbisfile3 \
        libvorbisenc2 \
        libogg0 \
        libuchardet0 \
        # extDB3
        libtbb-dev \
    # Cleanup
    && apt-get remove --purge -y \
    && apt-get clean autoclean \
    && apt-get autoremove -y \
    && rm -rf /var/lib/apt/lists/* \
    # SteamCMD
    && mkdir -p /steamcmd \
    && wget -qO- 'https://steamcdn-a.akamaihd.net/client/installer/steamcmd_linux.tar.gz' | tar zxf - -C /steamcmd

EXPOSE 2302/udp
EXPOSE 2303/udp
EXPOSE 2304/udp
EXPOSE 2305/udp
EXPOSE 2306/udp

WORKDIR /arma3server

VOLUME /steamcmd

STOPSIGNAL SIGINT