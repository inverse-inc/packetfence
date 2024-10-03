FROM debian:12

# do not want docs
RUN printf 'path-exclude /usr/share/doc/*\npath-include /usr/share/doc/*/copyright\npath-exclude /usr/share/man/*\npath-exclude /usr/share/groff/*\npath-exclude /usr/share/info/*\npath-exclude /usr/share/lintian/*\npath-exclude /usr/share/linda/*' > /etc/dpkg/dpkg.cfg.d/01_nodoc

# Prepare container with deps
RUN apt-get -qq update && \
    apt-get -qq --no-install-recommends install -y aptitude wget gnupg sudo && \
    apt-get -qq install -y curl

RUN /bin/bash -c "echo 'exit 0' > /usr/bin/systemctl"
RUN /bin/bash -c "echo 'exit 0' > /bin/systemctl"

ARG DOCKER_BUILD=yes
ARG PF_VERSION
ARG PKGS_TO_EXCLUDE

# This is to ensure a cache miss when there is a change in the dependencies
COPY debian/control /tmp/
COPY rpm/packetfence.spec /tmp/
COPY addons/dev-helpers/debian/install-pf-dependencies.sh /usr/local/pf/addons/dev-helpers/debian/install-pf-dependencies.sh

# Prepare Repos
RUN curl -fsSL https://inverse.ca/downloads/GPG_PUBLIC_KEY | gpg --dearmor -o /etc/apt/keyrings/packetfence.gpg && \
    /bin/bash -c "echo 'deb [signed-by=/etc/apt/keyrings/packetfence.gpg] http://inverse.ca/downloads/PacketFence/debian/${PF_VERSION} bookworm bookworm' > /etc/apt/sources.list.d/packetfence_deps.list"  && \
    curl -fsSL https://deb.nodesource.com/gpgkey/nodesource-repo.gpg.key | gpg --dearmor -o /etc/apt/keyrings/nodesource-repo.gpg && \
    /bin/bash -c "echo 'deb [signed-by=/etc/apt/keyrings/nodesource-repo.gpg] https://deb.nodesource.com/node_20.x nodistro main' > /etc/apt/sources.list.d/nodejs.list" && \
    apt-get -qq update

# Install Deps
RUN /usr/local/pf/addons/dev-helpers/debian/install-pf-dependencies.sh && \
    rm -f /usr/local/fingerbank/db/fingerbank_*.db && \
    apt-get -qq --no-install-recommends install -y freeradius-common && \
    apt-get -qq --no-install-recommends -y install localepurge && \
    printf '#USE_DPKG\nMANDELETE\nDONTBOTHERNEWLOCALE\n#SHOWFREEDSPACE\n#QUICKNDIRTYCALC\n#VERBOSE\nen' > /etc/locale.nopurge && \
    /usr/sbin/localepurge

# Clean
RUN apt-get -qq remove --purge -y locales-all localepurge && \
    apt-get clean && \
    rm -rf /etc/locale.nopurge && \
    find /usr/share/doc -depth -type f ! -name copyright -exec rm {} \; && \
    find /usr/share/doc -type d -empty -delete && \
    rm -rf /usr/share/groff/* /usr/share/info/* && \
    rm -rf /usr/share/lintian/* /usr/share/linda/* /var/cache/man/*

RUN useradd -U -r -d "/usr/local/pf" -s /bin/sh -c "PacketFence" -M pf

RUN mkdir -p /usr/local/pf/lib/ && \
    ln -s /usr/local/fingerbank/lib/fingerbank /usr/local/pf/lib/fingerbank

RUN chown -R pf: /usr/local/pf
