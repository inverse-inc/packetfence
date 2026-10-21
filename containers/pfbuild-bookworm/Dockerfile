FROM debian:bookworm

ENV PATH=/usr/local/go/bin:$PATH

ARG GOVERSION
ARG PF_MINOR_RELEASE

# python3 + nacl + requests: addons/packetfence-perl/psono.py fetches build secrets.
RUN apt-get update && \
    apt-get install -y --no-install-recommends ca-certificates curl gnupg devscripts equivs make git tree \
        python3 python3-nacl python3-requests && \
    install -d -m 0755 /etc/apt/keyrings && \
    curl -fsSL https://inverse.ca/downloads/GPG_PUBLIC_KEY \
        | gpg --dearmor -o /etc/apt/keyrings/packetfence.gpg && \
    curl -fsSL https://deb.nodesource.com/gpgkey/nodesource-repo.gpg.key \
        | gpg --dearmor -o /etc/apt/keyrings/nodesource-repo.gpg && \
    echo "deb [signed-by=/etc/apt/keyrings/packetfence.gpg] http://inverse.ca/downloads/PacketFence/debian/${PF_MINOR_RELEASE} bookworm bookworm" \
        > /etc/apt/sources.list.d/packetfence.list && \
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
