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
ARG source=https://github.com/inverse-inc/freeradius-server.git
ARG release=feature/PacketFence_3.2
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
