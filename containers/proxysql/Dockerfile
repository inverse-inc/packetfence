ARG KNK_REGISTRY_URL
ARG IMAGE_TAG
ARG from=${KNK_REGISTRY_URL}/pfbuild-debian-trixie:${IMAGE_TAG}

FROM ${from} AS build

# ProxySQL's deb-compliant entrypoint reads these
ENV MAKE=make
ENV CURVER=3.0.5
ENV PKG_RELEASE=debian13
ENV PROXYSQL_BUILD_TYPE=clickhouse
ENV BLD_NAME=proxysql
ENV CC=cc
ENV CXX=g++

ARG DEBIAN_FRONTEND=noninteractive

# Build dependencies of ProxySQL 3.x (inverse-inc/proxysql
# docker/local_builder/generate-deps.sh); go comes with pfbuild
RUN apt-get -qq update && \
    apt-get -qq install -y --no-install-recommends \
        automake bison bzip2 cmake equivs flex g++ gawk gcc git \
        libevent-dev libgnutls28-dev libicu-dev libmariadb-dev libncurses-dev \
        libssl-dev libsystemd-dev libtirpc-dev libtool libunwind-dev make \
        openssl patch python3 uuid-dev && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*

WORKDIR /opt

# pxc_scheduler_handler, run by the proxysql scheduler (conf/proxysql.conf.example)
ARG source_pxc=https://github.com/fdurand/pxc_scheduler_handler.git
ARG COMMIT_ID_PXC=1ee986f38e48607d1f5ed51242ebbf8fb3ec5e2e
RUN git clone -qq ${source_pxc}
WORKDIR /opt/pxc_scheduler_handler
RUN git checkout -q ${COMMIT_ID_PXC} && go build

# ProxySQL 3.0.5 with the sd_notify patch (Type=notify in
# packetfence-proxysql.service), branch feature/packetfence_systemd_notify
ARG source=https://github.com/inverse-inc/proxysql.git
ARG COMMIT_ID=7f54ab39c2f95f2ce40f57dcd7c1f4b7c55478c4
WORKDIR /opt
RUN git clone -qq ${source}
WORKDIR /opt/proxysql
RUN git checkout -q ${COMMIT_ID}

# Build the server and its .deb into binaries/
# GIT_VERSION: the fork's v3.0.5 tag is lightweight, so the Makefile's plain
# "git describe" would report v2.4.2 (the nearest annotated tag)
RUN mkdir -p /root/ctl && \
    cp -r docker/images/proxysql/deb-compliant/ctl/* /root/ctl/ && \
    GIT_VERSION=$(git describe --tags --long --abbrev=7) \
    MAKEOPT="-j$(nproc)" docker/images/proxysql/deb-compliant/entrypoint/entrypoint.bash

#
#  Clean environment and run the server
#
FROM ${KNK_REGISTRY_URL}/pfdebian-trixie:${IMAGE_TAG}

COPY --from=build /opt/pxc_scheduler_handler/pxc_scheduler_handler /pxc_scheduler_handler
COPY --from=build /opt/proxysql/binaries/*.deb /tmp/

RUN apt-get -qq update \
    && apt-get -qq install -y /tmp/proxysql_*.deb default-mysql-client \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/* /tmp/*.deb

COPY bin/proxysql-read-only-handler.sh /proxysql-read-only-handler.sh
RUN chmod +x /proxysql-read-only-handler.sh
RUN mkdir -p /usr/local/pf/var/proxysql/

ENTRYPOINT ["proxysql", "-f", "-D", "/usr/local/pf/var/proxysql/", "-c", "/usr/local/pf/var/conf/proxysql.conf", "--initial", "--idle-threads"]
