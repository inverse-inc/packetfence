ARG GO_VERSION
ARG KNK_REGISTRY_URL
ARG IMAGE_TAG
FROM ${KNK_REGISTRY_URL}/pfbuild-debian-bullseye:${IMAGE_TAG}
RUN mkdir -p /usr/local/pf/ /html
WORKDIR /usr/local/pf/
COPY ./go /usr/local/pf/go
COPY ./lib /usr/local/pf/lib
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
# build web admin
RUN cd /html/pfappserver/root && \
    make vendor  && \
    make light-dist
# build and install html doc
# in /usr/local/pf/docs
RUN cd /usr/local/pf && \
    make SRC_HTMLDIR=/html html
# install all html/ files and directories
# in /usr/local/pf/html
RUN make SRC_HTMLDIR=/html html_install

FROM ${KNK_REGISTRY_URL}/pfdebian:${IMAGE_TAG}
WORKDIR /usr/local/pf/
COPY --from=0 /usr/local/pf/go/pfhttpd /usr/local/pf/sbin/pfhttpd
COPY --from=0 /usr/local/pf/go/httpdispatcher /usr/local/pf/sbin/httpdispatcher
COPY --from=0 /usr/local/pf/html /usr/local/pf/html
COPY --from=0 /usr/local/pf/docs /usr/local/pf/docs

ENTRYPOINT /usr/local/pf/sbin/pfhttpd -conf /usr/local/pf/conf/caddy-services/httpadmindispatcher.conf -log-name httpd.admin_dispatcher
