ARG GO_VERSION
ARG KNK_REGISTRY_URL
ARG IMAGE_TAG
FROM ${KNK_REGISTRY_URL}/pfbuild-debian-bullseye:${IMAGE_TAG}
RUN mkdir -p /usr/local/pf/
WORKDIR /usr/local/pf/
COPY ./go /usr/local/pf/go
COPY ./lib /usr/local/pf/lib
COPY ./config.mk /usr/local/pf/config.mk
COPY ./html /usr/local/pf/html
COPY ./docs /usr/local/pf/docs
COPY ./src /usr/local/pf/src
COPY ./config.mk /usr/local/pf/config.mk
COPY ./Makefile /usr/local/pf/Makefile
RUN cd /usr/local/pf/go/ && \
    make pfhttpd
RUN cd /usr/local/pf/html/pfappserver/root && \
    make vendor  && \
    make light-dist
# Documentation
COPY addons/vagrant/inventory/group_vars/winservers/domain_setup.yml /usr/local/pf/addons/vagrant/inventory/group_vars/winservers/domain_setup.yml
COPY addons/vagrant/inventory/group_vars/winservers/init_directory.yml /usr/local/pf/addons/vagrant/inventory/group_vars/winservers/init_directory.yml
RUN cd /usr/local/pf && \
    make html 
# install html
ARG NAME=pf
ARG PREFIX=/usr/local
ARG INSTALL=/usr/bin/install -c -D -m0644

RUN install -d -m0755 $(CURDIR)/debian/packetfence-doc$(PREFIX)/$(NAME)/docs && \
    for i in `find "docs" "(" -name "*.html" -or -iname "*.js" ")" -type f`; do \
      install -m0644 $$i $(CURDIR)/debian/packetfence-doc$(PREFIX)/$(NAME)/docs/; \
    done
# images
RUN make DESTDIR=$(CURDIR)/debian/packetfence-doc images

# html_install
RUN install -d -m0755 $(CURDIR)/debian/packetfence-pfappserver-javascript$(PREFIX)/$(NAME)/html/pfappserver/root && \
    for i in `find 'html/pfappserver/root/dist' -type f`; do \
      install -D -m0644 $$i $(CURDIR)/debian/packetfence-pfappserver-javascript$(PREFIX)/$(NAME)/$$i; \
    done

FROM ${KNK_REGISTRY_URL}/pfdebian:${IMAGE_TAG}
WORKDIR /usr/local/pf/
COPY ./config.mk /usr/local/pf/config.mk
COPY --from=0 /usr/local/pf/go/pfhttpd /usr/local/pf/sbin/pfhttpd
COPY --from=0 /usr/local/pf/go/httpdispatcher /usr/local/pf/sbin/httpdispatcher
COPY --from=0 /usr/local/pf/html /usr/local/pf/html
COPY --from=0 /usr/local/pf/docs /usr/local/pf/docs

ENTRYPOINT /usr/local/pf/sbin/pfhttpd -conf /usr/local/pf/conf/caddy-services/httpadmindispatcher.conf -log-name httpd.admin_dispatcher
