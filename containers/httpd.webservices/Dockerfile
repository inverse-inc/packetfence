ARG KNK_REGISTRY_URL
ARG IMAGE_TAG
FROM ${KNK_REGISTRY_URL}/pfdebian:${IMAGE_TAG}

WORKDIR /usr/local/pf/

RUN mkdir -p /usr/local/pf/var/run
RUN mkdir -p /usr/local/pf/var/ssl_mutex

RUN chown -R pf: /usr/local/pf/var

COPY lib lib

COPY containers/pf-apache-wrapper containers/pf-apache-wrapper
RUN chmod +x containers/pf-apache-wrapper

ENTRYPOINT /usr/local/pf/containers/pf-apache-wrapper /usr/sbin/apache2 -f /usr/local/pf/var/conf/httpd.conf.d/httpd.webservices -DFOREGROUND
