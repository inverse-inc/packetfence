FROM debian:13

ENV PATH=/usr/local/go/bin:$PATH

ARG GOVERSION
# Unused until the PacketFence repo is added back (see below).
ARG PF_MINOR_RELEASE

# python3 + nacl + requests: addons/packetfence-perl/psono.py fetches build secrets.
# The PacketFence apt repo is not configured: debian/${PF_MINOR_RELEASE} has no
# trixie suite yet, and every Build-Depends in debian/control is in Debian
# trixie or NodeSource. Add it back (GPG_PUBLIC_KEY into
# /etc/apt/keyrings/packetfence.gpg + packetfence.list) once the third-party
# packages (addons/third-party/) are published for trixie.
RUN apt-get update && \
    apt-get install -y --no-install-recommends ca-certificates curl gnupg devscripts equivs make git \
        python3 python3-nacl python3-requests && \
    install -d -m 0755 /etc/apt/keyrings && \
    curl -fsSL https://deb.nodesource.com/gpgkey/nodesource-repo.gpg.key \
        | gpg --dearmor -o /etc/apt/keyrings/nodesource-repo.gpg && \
    echo "deb [signed-by=/etc/apt/keyrings/nodesource-repo.gpg] https://deb.nodesource.com/node_20.x nodistro main" \
        > /etc/apt/sources.list.d/nodejs.list && \
    apt-get update && \
    apt-get -y dist-upgrade

COPY debian/ /tmp/debian
RUN mk-build-deps --install --remove --tool "apt-get -q -y" /tmp/debian/control

# PACKER_BUILD_NAME triggers the script's short-circuit that skips `go mod download`.
COPY addons/dev-helpers/setup-go-env.sh /tmp/setup-go-env.sh
RUN GOVERSION=${GOVERSION} PACKER_BUILD_NAME=inDockerBuild /tmp/setup-go-env.sh

RUN gem install asciidoctor asciidoctor-pdf rouge

RUN rm -rf /tmp/debian /tmp/setup-go-env.sh && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*
