ARG from=debian:bullseye
ARG KNK_REGISTRY_URL
ARG IMAGE_TAG

FROM ${from} as build

ARG DEBIAN_FRONTEND=noninteractive

#
#  Install build tools
#
RUN apt-get -qq update
RUN apt-get -qq install -y devscripts equivs git quilt gcc libcollectdclient-dev

#
#  Create build directory
#
RUN mkdir -p /usr/local/src/repositories
WORKDIR /usr/local/src/repositories

#
#  Shallow clone the FreeRADIUS source
#
ARG source=https://github.com/fdurand/freeradius-server.git
ARG release=PacketFence_3.2-1

RUN git clone -qq --depth 1 --single-branch --branch ${release} ${source}
WORKDIR freeradius-server

#
#  Install build dependencies
#
RUN git checkout ${release}; \
    if [ -e ./debian/control.in ]; then \
        debian/rules debian/control; \
    fi; \
    echo 'y' | mk-build-deps -irt'apt-get -yV' debian/control

#
#  Build the server
#
# RUN make -j2 deb >/dev/null || make -j2 deb
RUN make -j2 deb

#
#  Clean environment and run the server
#
FROM ${KNK_REGISTRY_URL}/pfdebian:${IMAGE_TAG}

# Copy debian packages
COPY --from=build /usr/local/src/repositories/*.deb /tmp/

RUN apt-get -qq -y remove freeradius-common
RUN apt-get -qq -y remove freeradius-config
RUN apt-get -qq -y remove freeradius-dbg
RUN apt-get -qq -y remove freeradius-dhcp
RUN apt-get -qq -y remove freeradius-freetds
RUN apt-get -qq -y remove freeradius-iodbc
RUN apt-get -qq -y remove freeradius-krb5
RUN apt-get -qq -y remove freeradius-ldap
RUN apt-get -qq -y remove freeradius-memcached
RUN apt-get -qq -y remove freeradius-mysql
RUN apt-get -qq -y remove freeradius-perl-util
RUN apt-get -qq -y remove freeradius-postgresql
RUN apt-get -qq -y remove freeradius-redis
RUN apt-get -qq -y remove freeradius-rest
RUN apt-get -qq -y remove freeradius-utils
RUN apt-get -qq -y remove freeradius-yubikey
RUN apt-get -qq -y remove freeradius
RUN apt-get -qq -y remove libfreeradius-dev
RUN apt-get -qq -y remove libfreeradius3

RUN apt-get -qq update \
    && apt-get -qq install -y /tmp/*.deb \
    && apt-get clean \
    && rm -r /var/lib/apt/lists/* /tmp/*.deb \
    \
    && ln -s /etc/freeradius /etc/raddb

WORKDIR /usr/local/pf/

COPY lib lib

RUN mkdir -p /usr/local/pf/bin  && \
    mkdir -p /usr/local/pf/conf

# Minimal configuration files needed to start freeradius

COPY ./conf/pf.conf.defaults /usr/local/pf/conf/pf.conf.defaults

RUN touch /usr/local/pf/conf/pf.conf

COPY ./conf/chi.conf.defaults /usr/local/pf/conf/chi.conf.defaults

COPY ./conf/chi.conf.example /usr/local/pf/conf/chi.conf

COPY ./conf/pfconfig.conf.example /usr/local/pf/conf/pfconfig.conf

COPY ./conf/pfconfig.conf.defaults /usr/local/pf/conf/pfconfig.conf.defaults

COPY ./conf/log.conf.example /usr/local/pf/conf/log.conf

COPY ./bin/pflogger-packetfence /usr/local/pf/bin/pflogger-packetfence

COPY ./bin/pflogger.pl /usr/local/pf/bin/pflogger.pl

COPY ./config.mk /usr/local/pf/config.mk

RUN mkdir -p /usr/local/pf/var/run && \
    chown -R pf: /usr/local/pf/var

RUN sed -i 's#^socket\s*=.*#socket=/var/lib/mysql/mysql.sock#' /etc/mysql/my.cnf

