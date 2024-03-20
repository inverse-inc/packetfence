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
RUN cd /usr/local/pf/go/ &&  make pfcron

FROM ${KNK_REGISTRY_URL}/pfdebian:${IMAGE_TAG}
WORKDIR /usr/local/pf/
COPY --from=0 /usr/local/pf/go/pfcron /usr/local/pf/sbin/pfcron
ENTRYPOINT /usr/local/pf/sbin/pfcron
