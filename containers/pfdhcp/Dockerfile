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

# pfdhcp serves DHCP on the local interfaces (sockets bound to the interface,
# broadcast, raw sockets, ARP table): on a standalone server or a cluster it
# runs with the host network (--network=host). Its API listens on 22222.
EXPOSE 22222

ENTRYPOINT ["/usr/local/pf/sbin/pfdhcp"]
