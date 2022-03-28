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

FROM ${KNK_REGISTRY_URL}/pfdebian:${IMAGE_TAG}
WORKDIR /usr/local/pf/
COPY ./lib/pf/util/combined_dictionary /usr/local/pf/lib/pf/util/combined_dictionary
COPY ./raddb/dictionary /usr/local/pf/raddb/dictionary
COPY ./raddb/dictionary.inverse /usr/local/pf/raddb/dictionary.inverse
COPY ./raddb/dictionary.oauth2 /usr/local/pf/raddb/dictionary.oauth2
COPY ./raddb/dictionary.pfacct /usr/local/pf/raddb/dictionary.pfacct
COPY ./raddb/dictionary.ruckus /usr/local/pf/raddb/dictionary.ruckus
COPY ./raddb/dictionary.xirrus /usr/local/pf/raddb/dictionary.xirrus
COPY --from=0 /usr/local/pf/go/pfhttpd /usr/local/pf/sbin/pfhttpd
ENTRYPOINT /usr/local/pf/sbin/pfhttpd -conf /usr/local/pf/conf/caddy-services/api.conf -log-name api-frontend
