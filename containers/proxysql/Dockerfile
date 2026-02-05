ARG KNK_REGISTRY_URL
ARG IMAGE_TAG
ARG PROXYSQL_VERSION=3.0.5
ARG OPENSSL_VERSION=3.2.3

# Stage 1: Build OpenSSL 3.2+ from source
FROM debian:12 AS openssl-builder

ARG OPENSSL_VERSION

RUN apt-get update && apt-get install -y --no-install-recommends \
    build-essential \
    wget \
    ca-certificates \
    perl \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /tmp

RUN wget -q https://www.openssl.org/source/openssl-${OPENSSL_VERSION}.tar.gz \
    && tar xzf openssl-${OPENSSL_VERSION}.tar.gz \
    && cd openssl-${OPENSSL_VERSION} \
    && ./config --prefix=/opt/openssl --openssldir=/opt/openssl shared \
    && make -j$(nproc) \
    && make install_sw \
    && cd .. \
    && rm -rf openssl-${OPENSSL_VERSION}*

# Stage 2: Final image with proxysql
FROM ${KNK_REGISTRY_URL}/pfdebian:${IMAGE_TAG}

# Copy OpenSSL 3.2+ libraries from builder
COPY --from=openssl-builder /opt/openssl/lib64 /opt/openssl/lib64

# Configure library path so proxysql finds OpenSSL 3.2+ (use 00 prefix for priority)
RUN echo "/opt/openssl/lib64" > /etc/ld.so.conf.d/00-openssl.conf && ldconfig

ARG PROXYSQL_VERSION

# TODO: Replace with apt-get install once proxysql deb is in the repo
# RUN apt-get -qq update \
#     && apt-get clean \
#     && apt-get -qq install -y proxysql=${PROXYSQL_VERSION} default-mysql-client \
#     && apt-get clean

# For now, download and install proxysql deb with sd_notify patch
RUN apt-get -qq update \
    && apt-get -qq install -y wget default-mysql-client \
    && wget -q https://support.inverse.ca/~jgoimard/proxysql/proxysql_${PROXYSQL_VERSION}-debian12_amd64.deb -O /tmp/proxysql.deb \
    && apt-get -qq install -y -f /tmp/proxysql.deb \
    && rm -f /tmp/proxysql.deb \
    && apt-get clean

COPY bin/proxysql-read-only-handler.sh /proxysql-read-only-handler.sh
RUN chmod +x /proxysql-read-only-handler.sh
RUN mkdir -p /usr/local/pf/var/proxysql/

# Set LD_LIBRARY_PATH to ensure OpenSSL 3.2+ is used
# Set SSL_CERT_DIR to use system CA certificates
ENV LD_LIBRARY_PATH=/opt/openssl/lib64:$LD_LIBRARY_PATH
ENV SSL_CERT_DIR=/etc/ssl/certs
ENV SSL_CERT_FILE=/etc/ssl/certs/ca-certificates.crt

ENTRYPOINT ["proxysql", "-f", "-D", "/usr/local/pf/var/proxysql/", "-c", "/usr/local/pf/var/conf/proxysql.conf", "--initial", "--idle-threads"]
