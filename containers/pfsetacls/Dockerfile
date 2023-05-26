FROM golang:bullseye

ENV SEMAPHORE_VERSION="development" SEMAPHORE_ARCH="linux_amd64" \
    SEMAPHORE_CONFIG_PATH="${SEMAPHORE_CONFIG_PATH:-/etc/semaphore}" \
    APP_ROOT="/go/src/github.com/ansible-semaphore/semaphore/"

# hadolint ignore=DL3013
RUN apt update
RUN apt install -y gcc g++ git mariadb-client-10.5 python3 pip python3-openssl openssl ca-certificates curl libcurl4-openssl-dev openssh-client tini nodejs npm bash rsync && \
    apt install -y python3-dev libffi-dev &&\
    rm -rf /var/cache/apt/*

RUN pip3 install --upgrade pip cffi &&\
    pip3 install ansible

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

RUN cd $(go env GOPATH) && curl -sL https://taskfile.dev/install.sh | sh

RUN git config --global --add safe.directory /go/src/github.com/ansible-semaphore/semaphore

# Copy in app source
WORKDIR ${APP_ROOT}
RUN git clone https://github.com/ansible-semaphore/semaphore.git ./

RUN deployment/docker/dev/bin/install

USER semaphore
EXPOSE 3000
ENTRYPOINT ["/usr/local/bin/semaphore-wrapper"]
CMD ["./bin/semaphore", "server", "--config", "/etc/semaphore/config.json"]
