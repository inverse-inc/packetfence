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
ARG GO_CHECK=no
RUN if [ "$GO_CHECK" = "yes" ]; then make -C /usr/local/pf/go check; fi
RUN cd /usr/local/pf/go/ &&  make pfdhcp

FROM ${KNK_REGISTRY_URL}/pfdebian:${IMAGE_TAG}
WORKDIR /usr/local/pf/
COPY --from=0 /usr/local/pf/go/pfdhcp /usr/local/pf/sbin/pfdhcp

# Cloud deployment: no local DHCP interface, pfdhcp only serves the connector
# scopes over HTTP (POST /api/v1/dhcp/message on port 22222, called by
# pfconnector-server for the DHCP relays of the remote connectors).
ENV PFDHCP_DOH_ONLY=true
EXPOSE 22222

ENTRYPOINT ["/usr/local/pf/sbin/pfdhcp"]
