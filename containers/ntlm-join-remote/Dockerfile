ARG KNK_REGISTRY_URL
ARG IMAGE_TAG
FROM ${KNK_REGISTRY_URL}/pfbuild-debian-bookworm:${IMAGE_TAG}

RUN mkdir -p /usr/local/pf/
WORKDIR /usr/local/pf/

COPY go/go.mod /usr/local/pf/go/
COPY go/go.sum /usr/local/pf/go/
RUN cd /usr/local/pf/go/ && go mod download

COPY ./go /usr/local/pf/go
COPY ./lib /usr/local/pf/lib
COPY ./config.mk /usr/local/pf/config.mk
RUN cd /usr/local/pf/go/ &&  make ntlm-join-remote

FROM ${KNK_REGISTRY_URL}/pfdebian:${IMAGE_TAG}

WORKDIR /usr/local/pf/

COPY ./bin/impacket ./bin/impacket
COPY ./addons/ntlm-auth-api/openssl.cnf /etc/ssl/openssl.cnf

RUN ln -s /usr/local/pf/bin/impacket/impacket_addcomputer.py /usr/local/pf/bin/impacket-addcomputer && \
    chmod 0755 /usr/local/pf/bin/impacket/impacket_addcomputer.py

COPY --from=0 /usr/local/pf/go/ntlm-join-remote /usr/local/pf/sbin/ntlm-join-remote

ENTRYPOINT /usr/local/pf/sbin/ntlm-join-remote
