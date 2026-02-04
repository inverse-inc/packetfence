ARG KNK_REGISTRY_URL=ghcr.io/inverse-inc/packetfence
ARG IMAGE_TAG=devel
ARG PROXYSQL_VERSION=3.0.5
ARG PROXYSQL_BRANCH=v3.0.5
ARG from=${KNK_REGISTRY_URL}/pfbuild-debian-bookworm:${IMAGE_TAG}

FROM ${from} AS build

ARG PROXYSQL_VERSION
ARG PROXYSQL_BRANCH
ENV MAKE=make
ENV CURVER=${PROXYSQL_VERSION}
ENV PKG_RELEASE=debian12
ENV PROXYSQL_BUILD_TYPE=clickhouse
ENV BLD_NAME=proxysql
ENV CC=cc
ENV CXX=g++

ARG DEBIAN_FRONTEND=noninteractive

# Install build dependencies based on version
COPY generate-deps.sh install-deps.sh /tmp/
RUN chmod +x /tmp/*.sh && \
    /tmp/generate-deps.sh > /tmp/deps.conf && \
    /tmp/install-deps.sh "${PROXYSQL_VERSION}" /tmp/deps.conf

WORKDIR /opt

# Clone and build pxc_scheduler_handler
ARG source_pxc=https://github.com/fdurand/pxc_scheduler_handler.git
ARG COMMIT_ID_PXC=1ee986f38e48607d1f5ed51242ebbf8fb3ec5e2e
RUN git clone -qq ${source_pxc}
WORKDIR pxc_scheduler_handler
RUN git checkout $COMMIT_ID_PXC && go build

# Clone proxysql from upstream
ARG source=https://github.com/sysown/proxysql.git
WORKDIR /opt
RUN mkdir -p /root/ctl && git clone -qq ${source}
WORKDIR proxysql
RUN git checkout ${PROXYSQL_BRANCH}

# Apply the sd_notify patch (version-specific)
COPY 0001-sd_notify-patch-*.patch /tmp/
RUN MAJOR_MINOR=$(echo ${CURVER} | cut -d. -f1,2) && \
    PATCH_FILE="/tmp/0001-sd_notify-patch-${MAJOR_MINOR}.patch" && \
    if [ -f "$PATCH_FILE" ]; then \
        echo "Applying patch: $PATCH_FILE"; \
        git apply "$PATCH_FILE"; \
    else \
        PATCH_FILE="/tmp/0001-sd_notify-patch-${CURVER}.patch"; \
        if [ -f "$PATCH_FILE" ]; then \
            echo "Applying patch: $PATCH_FILE"; \
            git apply "$PATCH_FILE"; \
        else \
            echo "ERROR: No patch file found for version ${CURVER}"; \
            exit 1; \
        fi; \
    fi

# Build the server
RUN if [ -d "docker/images/proxysql/deb-compliant/ctl" ]; then \
        cp -r docker/images/proxysql/deb-compliant/ctl/* /root/ctl/; \
    else \
        cp -r docker/images/proxysql/deb-compliant/latest-package/ctl/* /root/ctl/; \
    fi
RUN MAKEOPT="-j$(nproc)" docker/images/proxysql/deb-compliant/entrypoint/entrypoint.bash

# Final stage - minimal image with artifacts
ARG KNK_REGISTRY_URL
ARG IMAGE_TAG
FROM ${KNK_REGISTRY_URL}/pfdebian:${IMAGE_TAG}

COPY --from=build /opt/pxc_scheduler_handler/pxc_scheduler_handler /pxc_scheduler_handler
COPY --from=build /opt/proxysql/binaries/*.deb /tmp/
