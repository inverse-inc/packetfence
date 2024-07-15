ARG KNK_REGISTRY_URL
ARG IMAGE_TAG
FROM ${KNK_REGISTRY_URL}/pfbuild-debian-bookworm:${IMAGE_TAG}

SHELL ["/bin/bash", "-c"]

RUN mkdir -p /usr/local/pf/ /html
WORKDIR /usr/local/pf/

COPY go/go.mod /usr/local/pf/go/
COPY go/go.sum /usr/local/pf/go/
RUN cd /usr/local/pf/go/ && go mod download

COPY ./go /usr/local/pf/go
COPY ./lib /usr/local/pf/lib
COPY ./html/swagger-ui /usr/local/pf/html/swagger-ui
# src html is copy into a temp directory (/html)
# then move to /usr/local/pf/html
COPY ./html /html
COPY ./docs /usr/local/pf/docs
COPY ./src /usr/local/pf/src
COPY ./config.mk /usr/local/pf/config.mk
COPY ./Makefile /usr/local/pf/Makefile
COPY ./conf/pf-release /usr/local/pf/conf/pf-release
RUN cd /usr/local/pf/go/ && \
    make pfhttpd

ARG BUILD_PFAPPSERVER_VUE

# Install nodejs if needed
RUN if [[ "$BUILD_PFAPPSERVER_VUE" == "yes" ]]; then \
      apt install nodejs -y && \
# build web admin
      cd /html/pfappserver/root && \
        make vendor  && \
        make light-dist && \
# build and install html doc
# in /usr/local/pf/docs
      cd /usr/local/pf && \
        make SRC_HTMLDIR=/html html  && \
# install html/ files and directories
# in /usr/local/pf/html
      cd /usr/local/pf && \
        make SRC_HTMLDIR=/html html_httpd.admin_dispatcher ; \
    else \
      echo "Skipping this step..." && \
      mkdir -p /usr/local/pf/html ; \
    fi

FROM ${KNK_REGISTRY_URL}/pfdebian:${IMAGE_TAG}
WORKDIR /usr/local/pf/
COPY --from=0 /usr/local/pf/go/pfhttpd /usr/local/pf/sbin/pfhttpd
COPY --from=0 /usr/local/pf/go/httpdispatcher /usr/local/pf/sbin/httpdispatcher
COPY --from=0 /usr/local/pf/html /usr/local/pf/html
COPY --from=0 /usr/local/pf/docs /usr/local/pf/docs

ENTRYPOINT /usr/local/pf/sbin/pfhttpd run --adapter caddyfile -c /usr/local/pf/conf/caddy-services/httpadmindispatcher.conf
