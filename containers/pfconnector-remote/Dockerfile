ARG KNK_REGISTRY_URL
ARG IMAGE_TAG

# Stage 0: Build pfconnector Go binary
FROM ${KNK_REGISTRY_URL}/pfbuild-debian-bookworm:${IMAGE_TAG} AS go-builder
RUN mkdir -p /usr/local/pf/
WORKDIR /usr/local/pf/

COPY go/go.mod /usr/local/pf/go/
COPY go/go.sum /usr/local/pf/go/
RUN cd /usr/local/pf/go/ && go mod download

COPY ./go /usr/local/pf/go
COPY ./lib /usr/local/pf/lib
COPY ./config.mk /usr/local/pf/config.mk
RUN cd /usr/local/pf/go/ && make pfconnector

# Stage 1: Runtime image with s6-overlay
FROM ${KNK_REGISTRY_URL}/radiusd:${IMAGE_TAG}

# Install s6-overlay v3
ARG S6_OVERLAY_VERSION=3.1.6.2
ADD https://github.com/just-containers/s6-overlay/releases/download/v${S6_OVERLAY_VERSION}/s6-overlay-noarch.tar.xz /tmp
ADD https://github.com/just-containers/s6-overlay/releases/download/v${S6_OVERLAY_VERSION}/s6-overlay-x86_64.tar.xz /tmp
RUN tar -C / -Jxpf /tmp/s6-overlay-noarch.tar.xz && \
    tar -C / -Jxpf /tmp/s6-overlay-x86_64.tar.xz && \
    rm -f /tmp/s6-overlay-*.tar.xz

# Install packages needed by radiusd-auth and fingerbank-collector
# fingerbank-collector-remote postinst tries to talk to systemd, so we
# temporarily provide a no-op systemctl to let the install succeed.
RUN ln -sf /bin/true /usr/local/bin/systemctl && \
    apt-get update && \
    apt-get install -y packetfence-ntlm-wrapper fingerbank-collector-remote && \
    apt-get clean && rm -rf /var/lib/apt/lists/* && \
    rm -f /usr/local/bin/systemctl

# Copy pfconnector binary from build stage
COPY --from=go-builder /usr/local/pf/go/pfconnector /usr/local/pf/sbin/pfconnector

# Copy s6 service definitions
COPY containers/pfconnector-remote/rootfs /

ENTRYPOINT ["/init"]
