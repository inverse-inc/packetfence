FROM debian:11

# Install Go 1.25.9 on debian:11 (bullseye)
# golang:*-bullseye images no longer exist on Docker Hub, so we install Go
# from the official tarball with SHA256 + GPG verification (same as docker-library/golang)
# Go 1.25+ is required because packr's dependency golang.org/x/sync@v0.20.0 needs it
RUN apt-get update && apt-get install -y --no-install-recommends \
        curl ca-certificates wget gnupg git openssh-client \
        g++ gcc libc6-dev make pkg-config \
    && rm -rf /var/lib/apt/lists/* \
    && curl -sL -o /tmp/go.tar.gz https://go.dev/dl/go1.25.9.linux-amd64.tar.gz \
    && echo '00859d7bd6defe8bf84d9db9e57b9a4467b2887c18cd93ae7460e713db774bc1 /tmp/go.tar.gz' | sha256sum -c - \
    && curl -sL -o /tmp/go.tar.gz.asc https://go.dev/dl/go1.25.9.linux-amd64.tar.gz.asc \
    && GNUPGHOME="$(mktemp -d)" \
    && export GNUPGHOME \
    && gpg --batch --keyserver keyserver.ubuntu.com --recv-keys 'EB4C 1BFD 4F04 2F6D DDCC  EC91 7721 F63B D38B 4796' \
    && gpg --batch --keyserver keyserver.ubuntu.com --recv-keys '2F52 8D36 D67B 69ED F998  D857 78BD 6547 3CB3 BD13' \
    && gpg --batch --verify /tmp/go.tar.gz.asc /tmp/go.tar.gz \
    && gpgconf --kill all \
    && rm -rf "$GNUPGHOME" /tmp/go.tar.gz.asc \
    && tar -C /usr/local -xzf /tmp/go.tar.gz \
    && rm /tmp/go.tar.gz

ENV GOTOOLCHAIN=local
ENV GOPATH=/go
ENV PATH=$GOPATH/bin:/usr/local/go/bin:$PATH
RUN mkdir -p "$GOPATH/src" "$GOPATH/bin" && chmod -R 1777 "$GOPATH"

ENV SEMAPHORE_VERSION="development" SEMAPHORE_ARCH="linux_amd64" \
    SEMAPHORE_CONFIG_PATH="${SEMAPHORE_CONFIG_PATH:-/etc/semaphore}" \
    APP_ROOT="/go/src/github.com/ansible-semaphore/semaphore/"

# hadolint ignore=DL3013
RUN curl -fsSL https://deb.nodesource.com/setup_16.x | bash -

RUN apt update && apt install -y gcc g++ make git mariadb-client-10.5 python3 pip python3-openssl openssl ca-certificates curl libcurl4-openssl-dev openssh-client tini nodejs bash rsync && \
    apt install -y python3-dev libffi-dev python3-paramiko &&\
    rm -rf /var/cache/apt/*

RUN pip3 install --upgrade pip cffi &&\
    pip3 install ansible && pip3 install ansible-pylibssh

RUN adduser --disabled-password -u 1002 --gecos 0 semaphore && \
    mkdir -p /go/src/github.com/ansible-semaphore/semaphore && \
    mkdir -p /tmp/semaphore && \
    mkdir -p /etc/semaphore && \
    mkdir -p /var/lib/semaphore && \
    chown -R semaphore:0 /go && \
    chown -R semaphore:0 /tmp/semaphore && \
    chown -R semaphore:0 /etc/semaphore && \
    chown -R semaphore:0 /var/lib/semaphore && \
    ssh-keygen -t rsa -q -f "/root/.ssh/id_rsa" -N ""       && \
    ssh-keyscan -H github.com > /root/.ssh/known_hosts

RUN cd $(go env GOPATH) && curl -sL https://taskfile.dev/install.sh | sh -s -- "v3.33.0"

RUN npm install -g npm@9.6.7

RUN git config --global --add safe.directory /go/src/github.com/ansible-semaphore/semaphore

# Copy in app source
WORKDIR ${APP_ROOT}
ARG source=https://github.com/ansible-semaphore/semaphore.git
ARG release=v2.8.90

RUN git clone -qq --depth 1 --single-branch --branch ${release} ${source} ./

# Generate version.go before the build since the compile:fe2 task (vue-cli-service)
# may fail and it would prevent compile:be from generating it
RUN go run util/version_gen/generator.go ${release}

RUN deployment/docker/ci/bin/install

USER semaphore
EXPOSE 3000
ENTRYPOINT ["/usr/local/bin/semaphore-wrapper"]
CMD ["./bin/semaphore", "server", "--config", "/etc/semaphore/config.json"]
