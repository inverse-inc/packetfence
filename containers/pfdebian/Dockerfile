FROM debian:12

RUN apt-get update && apt-get install -y aptitude wget gnupg

RUN /bin/bash -c "echo 'exit 0' > /usr/bin/systemctl"
RUN /bin/bash -c "echo 'exit 0' > /bin/systemctl"

ARG DOCKER_BUILD=yes
ARG PF_VERSION
ARG PKGS_TO_EXCLUDE

# This is to ensure a cache miss when there is a change in the dependencies
COPY debian/control /tmp/
COPY rpm/packetfence.spec /tmp/

RUN /bin/bash -c "echo 'deb http://inverse.ca/downloads/PacketFence/debian/${PF_VERSION} bookworm bookworm' > /etc/apt/sources.list.d/packetfence_deps.list"  && \
    wget -q -O - https://inverse.ca/downloads/GPG_PUBLIC_KEY | apt-key add -

RUN /bin/bash -c "echo 'deb https://deb.nodesource.com/node_20.x nodistro main' > /etc/apt/sources.list.d/nodejs.list" && \
    wget -q -O - https://deb.nodesource.com/gpgkey/nodesource-repo.gpg.key | apt-key add -

RUN apt-get update

COPY addons/dev-helpers/debian/install-pf-dependencies.sh /usr/local/pf/addons/dev-helpers/debian/install-pf-dependencies.sh
RUN /usr/local/pf/addons/dev-helpers/debian/install-pf-dependencies.sh && \
      rm -f /usr/local/fingerbank/db/fingerbank_*.db

RUN apt-get install -y freeradius-common

RUN useradd -U -r -d "/usr/local/pf" -s /bin/sh -c "PacketFence" -M pf

RUN mkdir -p /usr/local/pf/lib/ && \
    ln -s /usr/local/fingerbank/lib/fingerbank /usr/local/pf/lib/fingerbank

RUN chown -R pf: /usr/local/pf

# To be removed
RUN apt-get install -y libcisco-accesslist-parser-perl libparse-eyapp-perl
