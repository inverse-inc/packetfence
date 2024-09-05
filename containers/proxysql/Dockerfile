ARG KNK_REGISTRY_URL
ARG IMAGE_TAG
ARG from=${KNK_REGISTRY_URL}/pfbuild-debian-bookworm:${IMAGE_TAG}

FROM ${from} as build

ENV MAKE=make
ENV MAKEOPT="-j 1"
ENV CURVER=2.6.0
ENV PKG_RELEASE=debian12
ENV PROXYSQL_BUILD_TYPE=clickhouse
ENV CC=cc
ENV CXX=g++

ARG DEBIAN_FRONTEND=noninteractive

# Install build dependencies

RUN apt-get update && apt-get install -y \
        automake \
        equivs \
        cmake \
        make \
        g++ \
        gcc \
        gdb \
        gdbserver \
        git \
        libgnutls28-dev \
        libmariadb-dev \
        libssl-dev \
        libtool \
        gawk \
        bzip2 \
        python3 \
        uuid-dev \
        libsystemd-dev \
        systemd \
  && \
  apt-get clean && \
  rm -rf /var/lib/apt/lists/

#
#  Create build directory
#
RUN mkdir -p /opt
WORKDIR /opt

#
# Shallow clone the pxc_scheduler_handler source
#

ARG source_pxc=https://github.com/fdurand/pxc_scheduler_handler.git
ARG COMMIT_ID_PXC=1ee986f38e48607d1f5ed51242ebbf8fb3ec5e2e
RUN git clone -qq ${source_pxc}
WORKDIR pxc_scheduler_handler
RUN git checkout $COMMIT_ID_PXC
RUN go build

#
#  Shallow clone the proxysql source
#
ARG source=https://github.com/inverse-inc/proxysql.git

WORKDIR /opt

RUN mkdir -p /root/ctl
ARG COMMIT_ID=47368be71ffcb70af664d751bafdae3b23087e84
RUN git clone -qq ${source}
WORKDIR proxysql
RUN git checkout $COMMIT_ID

#
#  Build the server
#
RUN cp -r docker/images/proxysql/deb-compliant/latest-package/ctl/* /root/ctl/
RUN docker/images/proxysql/deb-compliant/entrypoint/entrypoint.bash

#
#  Clean environment and run the server
#
FROM ${KNK_REGISTRY_URL}/pfdebian:${IMAGE_TAG}

COPY --from=build /opt/pxc_scheduler_handler/pxc_scheduler_handler /pxc_scheduler_handler
COPY --from=build /opt/proxysql/binaries/*.deb /tmp/

RUN apt-get -qq update \
    && apt-get clean \
    && apt-get -qq install -y /tmp/*.deb \
    && apt-get clean \
    && rm -r /var/lib/apt/lists/* /tmp/*.deb

COPY bin/proxysql-read-only-handler.sh /proxysql-read-only-handler.sh
RUN chmod +x /proxysql-read-only-handler.sh
RUN mkdir -p /usr/local/pf/var/proxysql/

ENTRYPOINT ["proxysql", "-f", "-D", "/usr/local/pf/var/proxysql/", "-c", "/usr/local/pf/var/conf/proxysql.conf", "--initial", "--idle-threads"]
