ARG KNK_REGISTRY_URL
ARG IMAGE_TAG
FROM ${KNK_REGISTRY_URL}/pfdebian:${IMAGE_TAG}

WORKDIR /usr/local/pf/

COPY bin/pfcmd.pl bin/pfcmd.pl
RUN ln -s /usr/local/pf/bin/pfcmd.pl /usr/local/pf/bin/pfcmd

RUN mkdir -p /usr/local/pf/var/run
RUN mkdir -p /usr/local/pf/var/ssl_mutex

RUN chown -R pf: /usr/local/pf/var

COPY lib lib

ENTRYPOINT /usr/sbin/apache2 -f /usr/local/pf/var/conf/httpd.conf.d/httpd.webservices -DFOREGROUND
