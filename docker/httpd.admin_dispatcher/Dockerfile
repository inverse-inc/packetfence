ARG GO_VERSION
ARG KNK_REGISTRY_URL
ARG IMAGE_TAG
FROM golang:${GO_VERSION}
RUN mkdir -p /usr/local/pf/
WORKDIR /usr/local/pf/
COPY ./go /usr/local/pf/go
COPY ./lib /usr/local/pf/lib
COPY ./config.mk /usr/local/pf/config.mk
RUN cd /usr/local/pf/go/ &&  make pfhttpd
RUN cd /usr/local/pf/go/ &&  make httpdispatcher

FROM ${KNK_REGISTRY_URL}/pfdebian:${IMAGE_TAG}
WORKDIR /usr/local/pf/
COPY ./html /usr/local/pf/html
COPY ./docs /usr/local/pf/docs
COPY ./config.mk /usr/local/pf/config.mk
COPY --from=0 /usr/local/pf/go/pfhttpd /usr/local/pf/sbin/pfhttpd
COPY --from=0 /usr/local/pf/go/httpdispatcher /usr/local/pf/sbin/httpdispatcher
ENTRYPOINT /usr/local/pf/sbin/pfhttpd -conf /usr/local/pf/conf/caddy-services/httpadmindispatcher.conf -log-name httpd.admin_dispatcher
