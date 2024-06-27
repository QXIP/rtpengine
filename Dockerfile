##
## Build rtpengine from source
##
FROM debian:bookworm AS builder

WORKDIR /build

ARG TAG_NAME=master
ENV DEBIAN_FRONTEND noninteractive

RUN apt-get update && apt-get -y install build-essential git curl kmod linux-headers-$(uname -r) linux-image-$(uname -r) \
  && echo 'man-db man-db/auto-update boolean false' | debconf-set-selections \
  && git clone https://github.com/sipwise/rtpengine \
  && cd rtpengine \
  && git checkout ${TAG_NAME} \
  && apt-get -y build-dep -Ppkg.ngcp-rtpengine.nobcg729 . \
  && dpkg-buildpackage -Ppkg.ngcp-rtpengine.nobcg729 \
  && curl -qL -o /usr/bin/netdiscover https://github.com/CyCoreSystems/netdiscover/releases/download/v1.2.5/netdiscover.linux.amd64 \
  && chmod +x /usr/bin/netdiscover

## Build xt_RTPENGINE.ko
RUN cd rtpengine/kernel-module && make && ls -alF *.ko

##
## Runner
##
FROM debian:bookworm

WORKDIR /opt/rtpengine

ENV DEBIAN_FRONTEND noninteractive

RUN groupadd -r rtpengine && useradd -r -g rtpengine rtpengine

# NOTE: To include in-kernel operations and recording copy the entire build folder
COPY --from=builder /build/ngcp-rtpengine-daemon_*.deb /tmp/
COPY --from=builder /build/ngcp-rtpengine-recording-daemon_*.deb /tmp/
COPY --from=builder /build/ngcp-rtpengine-kernel-dkms_*.deb /tmp/
COPY --from=builder /build/ngcp-rtpengine-utils_*.deb /tmp/
COPY --from=builder /build/kernel-module/xt_RTPENGINE.ko /tmp/
COPY --from=builder /usr/bin/netdiscover /usr/bin/netdiscover

RUN apt-get update && \
  mkdir -p /etc/modprobe.d/ && \
  apt-get install -y \
  curl \
  iptables \
  libavcodec59 \
  libavformat59 \
  libavutil57 \
  libevent-2.1-7 \
  libevent-pthreads-2.1-7 \
  libglib2.0-0 \
  libhiredis0.14 \
  libip4tc2 \
  libip6tc2 \
  libjson-glib-1.0-0 \
  libmariadb3 \
  libmosquitto1 \
  libopus0 \
  libpcap0.8 \
  libspandsp2 \
  libssl3 \
  libswresample4 \
  libwebsockets17 \
  libxmlrpc-core-c3 && \
  apt-get -y install /tmp/*.deb && \
  rm -rf /var/lib/apt/lists/* /tmp/*.deb

RUN mkdir -p /lib/modules/$(uname -r)/updates \
    && cp /tmp/xt_RTPENGINE.ko /lib/modules/$(uname -r)/updates/

# Copy configuration files and entrypoint
COPY ./entrypoint.sh /opt/rtpengine/entrypoint.sh
COPY ./rtpengine.conf /opt/rtpengine/rtpengine.conf
COPY ./rtpengine-recording.conf /opt/rtpengine/rtpengine-recording.conf

RUN chown -R rtpengine:rtpengine . && \
  chmod +x entrypoint.sh

# USER rtpengine

ENTRYPOINT ["/opt/rtpengine/entrypoint.sh"]
CMD ["rtpengine"]
