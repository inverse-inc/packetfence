FROM debian:11

RUN apt-get update
RUN apt-get install -y aptitude wget gnupg

RUN /bin/bash -c "echo 'exit 0' > /usr/bin/systemctl"
RUN /bin/bash -c "echo 'exit 0' > /bin/systemctl"

ARG DOCKER_BUILD=yes
RUN /bin/bash -c "echo 'deb http://inverse.ca/downloads/PacketFence/debian/11.2 bullseye bullseye' > /etc/apt/sources.list.d/packetfence_deps.list"
RUN /bin/bash -c "echo 'deb http://inverse.ca/downloads/PacketFence/gitlab/486105969/debian bullseye main' > /etc/apt/sources.list.d/packetfence.list"
RUN wget -q -O - https://inverse.ca/downloads/GPG_PUBLIC_KEY | apt-key add -
RUN apt-get update
RUN /bin/bash -c "DEBIAN_FRONTEND=noninteractive apt-get install -f -y packetfence"

RUN rm -f /usr/local/fingerbank/db/fingerbank_*.db

