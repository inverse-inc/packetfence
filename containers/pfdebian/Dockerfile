FROM debian:11

RUN apt-get update && apt-get install -y aptitude wget gnupg

RUN /bin/bash -c "echo 'exit 0' > /usr/bin/systemctl"
RUN /bin/bash -c "echo 'exit 0' > /bin/systemctl"

ARG DOCKER_BUILD=yes
ARG PF_VERSION
ARG PKGS_TO_EXCLUDE
RUN /bin/bash -c "echo 'deb http://inverse.ca/downloads/PacketFence/debian/${PF_VERSION} bullseye bullseye' > /etc/apt/sources.list.d/packetfence_deps.list"
RUN wget -q -O - https://inverse.ca/downloads/GPG_PUBLIC_KEY | apt-key add -
RUN apt-get update

COPY addons/dev-helpers/debian/install-pf-dependencies.sh /usr/local/pf/addons/dev-helpers/debian/install-pf-dependencies.sh
RUN /usr/local/pf/addons/dev-helpers/debian/install-pf-dependencies.sh
RUN rm -f /usr/local/fingerbank/db/fingerbank_*.db

RUN useradd -U -r -d "/usr/local/pf" -s /bin/sh -c "PacketFence" -M pf

RUN mkdir -p /usr/local/pf/lib/
RUN ln -s /usr/local/fingerbank/lib/fingerbank /usr/local/pf/lib/fingerbank

RUN chown -R pf: /usr/local/pf
