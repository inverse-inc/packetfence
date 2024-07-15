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
RUN cd /usr/local/pf/go/ &&  make pfhttpd

FROM ${KNK_REGISTRY_URL}/pfdebian:${IMAGE_TAG}

WORKDIR /usr/local/pf/

COPY ./lib/pf/util/combined_dictionary /usr/local/pf/lib/pf/util/combined_dictionary
COPY ./raddb/dictionary.freeradius.evs5 ./raddb/dictionary ./raddb/dictionary.inverse ./raddb/dictionary.oauth2 ./raddb/dictionary.pfacct ./raddb/dictionary.ruckus ./raddb/dictionary.xirrus /usr/local/pf/raddb/
COPY html/pfappserver/root/errors/ html/pfappserver/root/errors/
COPY --from=0 /usr/local/pf/go/pfhttpd /usr/local/pf/sbin/pfhttpd

ENTRYPOINT /usr/local/pf/sbin/pfhttpd run --adapter caddyfile -c /usr/local/pf/conf/caddy-services/api.conf
