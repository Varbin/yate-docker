FROM debian:12-slim AS buildenv
# Prepare a common build environment. It will be exted if needed.
RUN apt-get update && apt-get install -y  \
    git build-essential yacc bison yasm flex pkg-config unzip tar autoconf patch doxygen \
    default-libmysqlclient-dev libpq-dev libsqlite3-dev libexpat-dev \
    libopus-dev libtheora-dev libspeex-dev libopencore-amrnb-dev libogg-dev libx264-dev libgsm1-dev libopencore-amrnb-dev libtiff-dev \
    libasound2-dev libsctp-dev libcapi20-dev dahdi-source libusb-1.0-0-dev \
    ca-certificates \
    --no-install-recommends
WORKDIR /usr/src

FROM buildenv AS celt
ADD --checksum=sha256:01c2579fba8b283c9068cb704a70a6e654aa74ced064c091cafffbe6fb1d4cbf http://downloads.xiph.org/releases/celt/celt-0.11.1.tar.gz /usr/src
RUN tar xf celt-*.tar.gz && cd celt-* && ./configure --prefix=/usr/local/ && make -j$(nproc) && make install

FROM buildenv AS ptlib
ADD --checksum=sha256:22653cbb7d94ceafea35a9eb0f8f96afe8f0ffc8cd4cb08ce00d6c62d5e11bb8 https://github.com/willamowius/ptlib/archive/v2_10_9_6.tar.gz /usr/src
RUN tar xf v*.tar.gz && cd ptlib-* && ./configure --prefix=/usr/local && make -j$(nproc) && make install

# Yate needs an old version of spandsp...
FROM buildenv AS spandsp
ADD --checksum=sha256:cef7139c6076dcd1b7efd6ab49eaf318cb86d9217d8d137a7f461875c9b78922 https://www.soft-switch.org/downloads/spandsp/old/spandsp-0.0.6pre16.tgz /usr/src
RUN tar xf spandsp-*.tgz && cd spandsp-* && ./configure && make -j$(nproc) && make install

# 'Someone' has to write a patch for modern ffmpeg version to h323+
# Also, I can't compile outdated ffmpeg with modern libh264 oder libx264...
#FROM buildenv AS ffmpeg
#ADD --checksum=40973d44970dbc83ef302b0609f2e74982be2d85916dd2ee7472d30678a7abe6 https://ffmpeg.org/releases/ffmpeg-7.1.tar.xz /usr/src
#RUN tar xf ffmpeg* &&  cd ffmpeg* && ./configure --prefix=/usr/local --enable-shared && make install

FROM buildenv AS openh323
# Actually h.323+
COPY --from=celt /usr/local/ /usr/local
COPY --from=ptlib /usr/local/ /usr/local
COPY --from=spandsp /usr/local/ /usr/local
ADD --checksum=sha256:d45ea651862ba6ef1e9e1240c7ab06a247d4083b02f8648a14c42921bd142db9 https://github.com/willamowius/h323plus/archive/v1_28_0.zip /usr/src
RUN unzip v* && cd h323plus-* && ./configure --enable-h460p  --enable-h460pre  --enable-h460com  --enable-h460im  --enable-h461  --enable-aec --enable-sbc  --enable-h248 --enable-t120 --enable-t140 --enable-sbc --enable-h235 --enable-h235.256 --enable-h249 --enable-h46017 --enable-h46026 --enable-h46025 && make -j$(nproc) && make install

FROM buildenv AS yate-build
COPY --from=openh323 /usr/local/ /usr/local
RUN git clone --depth 1 https://github.com/yatevoip/yate
ADD patch/*.patch /usr/src/yate
RUN set -e -x; cd yate && for patch in *.patch ; do \
      patch --strip=1 -i "$patch"; \
    done
RUN cd yate && ./autogen.sh && ./configure && make -j$(nproc) && make install

FROM debian:12-slim
RUN apt-get update && apt-get install -y \
    libmariadb3 libpq5 libsqlite3-0 libexpat1 libssl3 \
    libopus0 libtheora0 libspeex1 libopencore-amrnb0 libogg0 libx264-164 libgsm1 libopencore-amrnb0 libtiff6  \
    libasound2 libsctp1 libcapi20-3 libusb-1.0-0 \
    telnet ca-certificates \
    --no-install-recommends
COPY --from=yate-build /usr/local/ /usr/local
ENV LD_LIBRARY_PATH=/usr/local/lib
CMD ["/usr/local/bin/yate", "-vv"]

# Depending on your configuration, you may not need all ports or even more.
# IAX
EXPOSE 4569/udp
# SIP
EXPOSE 5060/udp
EXPOSE 5060/tcp
EXPOSE 5061/tcp
# H.323 (disabled by default)
EXPOSE 1719/udp
# (S)RTP
EXPOSE 16384-32768/udp
# SNMP (Monitoring)
EXPOSE 161/udp
# MGCP
EXPOSE 2427/udp

LABEL org.opencontainers.image.source=https://github.com/varbin/yate-docker
LABEL org.opencontainers.image.description="Yet another telephony exchange in a box."
LABEL org.opencontainers.image.licenses="GPL-2.0"

