ARG GO_VERSION
ARG KNK_REGISTRY_URL
ARG IMAGE_TAG
FROM ${KNK_REGISTRY_URL}/pfbuild-debian-bullseye:${IMAGE_TAG}
RUN mkdir -p /usr/local/pf/ /html
WORKDIR /usr/local/pf/
COPY ./go /usr/local/pf/go
COPY ./lib /usr/local/pf/lib
COPY ./config.mk /usr/local/pf/config.mk
COPY ./html /html
COPY ./docs /usr/local/pf/docs
COPY ./src /usr/local/pf/src
COPY ./config.mk /usr/local/pf/config.mk
COPY ./Makefile /usr/local/pf/Makefile
RUN cd /usr/local/pf/go/ && \
    make pfhttpd
# build web admin
RUN cd /usr/local/pf/html/pfappserver/root && \
    make vendor  && \
    make light-dist
# build and install html doc
RUN cd /usr/local/pf && \
    make html
# install all html/ files and directories
RUN make SRC_HTMLDIR=/html DESTDIR=/usr/local/pf html_install

FROM ${KNK_REGISTRY_URL}/pfdebian:${IMAGE_TAG}
WORKDIR /usr/local/pf/
COPY ./config.mk /usr/local/pf/config.mk
COPY --from=0 /usr/local/pf/go/pfhttpd /usr/local/pf/sbin/pfhttpd
COPY --from=0 /usr/local/pf/go/httpdispatcher /usr/local/pf/sbin/httpdispatcher
COPY --from=0 /usr/local/pf/html /usr/local/pf/html
COPY --from=0 /usr/local/pf/docs /usr/local/pf/docs

ENTRYPOINT /usr/local/pf/sbin/pfhttpd -conf /usr/local/pf/conf/caddy-services/httpadmindispatcher.conf -log-name httpd.admin_dispatcher
