ARG KNK_REGISTRY_URL
ARG IMAGE_TAG
ARG from=debian:bullseye
FROM ${from} as build

ARG DEBIAN_FRONTEND=noninteractive

#
#  Install build tools
#
RUN apt-get -qq update
RUN apt-get -qq install -y devscripts equivs git quilt gcc

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

RUN git clonei -qq --depth 1 --single-branch --branch ${release} ${source}
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
RUN make -j2 deb >/dev/null || make -j2 deb

#
#  Clean environment and run the server
#
FROM ${KNK_REGISTRY_URL}/pfdebian:${IMAGE_TAG}

COPY --from=build /usr/local/src/repositories/*.deb /tmp/

RUN apt-get -qq update \
    && apt-get -qq install -y /tmp/*.deb \
    && apt-get clean \
    && rm -r /var/lib/apt/lists/* /tmp/*.deb \
    \
    && ln -s /etc/freeradius /etc/raddb

WORKDIR /usr/local/pf/

RUN mkdir -p /usr/local/pf/var/run

RUN chown -R pf: /usr/local/pf/var
