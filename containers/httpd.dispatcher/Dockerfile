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
COPY ./html /usr/local/pf/html
COPY ./src /usr/local/pf/src
COPY ./config.mk /usr/local/pf/config.mk
COPY ./Makefile /usr/local/pf/Makefile

RUN cd /usr/local/pf/go/ && \
    make pfhttpd && \
    make httpdispatcher

RUN apt install nodejs -y && \
    cd /usr/local/pf/html/common && \
    make vendor  && \
    make light-dist

FROM ${KNK_REGISTRY_URL}/pfdebian:${IMAGE_TAG}
WORKDIR /usr/local/pf/
COPY --from=0 /usr/local/pf/html /usr/local/pf/html
COPY --from=0 /usr/local/pf/go/pfhttpd /usr/local/pf/sbin/pfhttpd
COPY --from=0 /usr/local/pf/go/httpdispatcher /usr/local/pf/sbin/httpdispatcher
ENTRYPOINT /usr/local/pf/sbin/pfhttpd run --adapter caddyfile -c /usr/local/pf/conf/caddy-services/httpdispatcher.conf
