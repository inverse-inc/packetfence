ARG from=debian:bullseye
FROM ${from} as build

ARG DEBIAN_FRONTEND=noninteractive

#
#  Install build tools
#
RUN apt-get update
RUN apt-get install -y devscripts equivs git quilt gcc

#
#  Create build directory
#
RUN mkdir -p /usr/local/src/repositories
WORKDIR /usr/local/src/repositories

#
#  Shallow clone the FreeRADIUS source
#
ARG source=https://github.com/fdurand/freeradius-server.git
ARG release=feature/PacketFence

RUN git clone --depth 1 --single-branch --branch ${release} ${source}
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
RUN make -j2 deb

#
#  Clean environment and run the server
#
FROM ${from}
COPY --from=build /usr/local/src/repositories/*.deb /tmp/

RUN apt-get update \
    && apt-get install -y /tmp/*.deb \
    && apt-get clean \
    && rm -r /var/lib/apt/lists/* /tmp/*.deb \
    \
    && ln -s /etc/freeradius /etc/raddb

RUN apt-get update
RUN apt-get install -y aptitude wget gnupg

RUN /bin/bash -c "echo 'deb http://inverse.ca/downloads/PacketFence/debian/11.3 bullseye bullseye' > /etc/apt/sources.list.d/packetfence_deps.list"
RUN wget -q -O - https://inverse.ca/downloads/GPG_PUBLIC_KEY | apt-key add -
RUN apt-get update

RUN wget https://raw.githubusercontent.com/inverse-inc/packetfence/devel/addons/dev-helpers/debian/install-pf-dependencies.sh

RUN chmod +x install-pf-dependencies.sh
RUN ./install-pf-dependencies.sh
RUN rm -f /usr/local/fingerbank/db/fingerbank_*.db

RUN useradd -U -r -d "/usr/local/pf" -s /bin/sh -c "PacketFence" -M pf

WORKDIR /usr/local/pf/

RUN mkdir -p /usr/local/pf/var/run

RUN chown -R pf: /usr/local/pf/var

EXPOSE 1815/udp
ENTRYPOINT /usr/sbin/freeradius -d /usr/local/pf/raddb -n cli -fm
#CMD ["/usr/sbin/freeradius","-d","/usr/local/pf/raddb","-n","acct","-fm"]
