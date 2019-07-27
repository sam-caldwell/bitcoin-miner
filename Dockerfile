#
#
#
FROM ubuntu:latest AS base_image

ENV VERSION=v0.18.0
ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update -y --fix-missing && \
    apt-get upgrade -y
#
#
#
FROM base_image AS build_image

RUN apt-get install -y build-essential \
		               libtool \
                       autotools-dev \
                       automake \
                       pkg-config \
                       bsdmainutils \
                       python3 \
                       libssl-dev \
                       libevent-dev \
                       libboost-system-dev \
                       libboost-filesystem-dev \
                       libboost-chrono-dev \
                       libboost-test-dev \
                       libboost-thread-dev \
                       libzmq3-dev \
                       doxygen \
                       apt-utils \
                       git-core
#
#
#
FROM build_image AS build_image_0

RUN cd /opt/ && \
    git clone https://github.com/bitcoin/bitcoin.git && \
    cd bitcoin && \
    git fetch --all && \
    git checkout tags/$VERSION -b $VERSION

WORKDIR /opt/bitcoin

RUN ./autogen.sh && \
    ./configure --enable-hardening \
                --disable-wallet \
                --without-gui \
                --without-miniupnpc \
                --with-incompatible-bdb \
                --enable-cxx \
                --disable-shared \
                --with-pic
#
#
#
FROM build_image_0 AS build_image_1
RUN make && \
    make install
#
#
#
FROM build_image_1 AS deploy_image
RUN strip $(which bitcoind)
RUN strip $(which bitcoin-cli)
RUN strip $(which bitcoin-tx)
RUN chmod 0555 $(which bitcoind)
RUN chmod 0555 $(which bitcoin-cli)
RUN chmod 0555 $(which bitcoin-tx)
RUN mkdir /opt/artifact
RUN cp $(which bitcoind) /opt/artifact/
RUN cp $(which bitcoin-cli) /opt/artifact/
RUN cp $(which bitcoin-tx) /opt/artifact/
#
#
#
FROM base_image as runtime_image

RUN apt-get install -y python3 \
                    libssl-dev \
                    libevent-dev \
                    libboost-system-dev \
                    libboost-filesystem-dev \
                    libboost-chrono-dev \
                    libboost-thread-dev \
                    libzmq3-dev

COPY --from=deploy_image /opt/artifact/bitcoind /usr/local/bin/bitcoind
COPY --from=deploy_image /opt/artifact/bitcoin-cli /usr/local/bin/bitcoin-cli
COPY --from=deploy_image /opt/artifact/bitcoin-tx /usr/local/bin/bitcoin-tx

RUN bitcoind -h 
RUN bitcoin-cli -h

RUN mkdir /opt/data && \
    mkdir /opt/wallet/

COPY bitcoin.conf /etc/bitcoin.conf

CMD [ "bitcoind", "-server", "-nodebuglogfile", "--printtoconsole", "-conf=/etc/bitcoin.conf" ]
