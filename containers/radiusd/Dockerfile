ARG KNK_REGISTRY_URL
ARG IMAGE_TAG

FROM ${KNK_REGISTRY_URL}/pfdebian:${IMAGE_TAG}

RUN apt-get -qq update \
    && apt-get clean \
    && apt-get -qq install -y freeradius=4:3.2.7+git freeradius-common=4:3.2.7+git freeradius-config=4:3.2.7+git freeradius-ldap=4:3.2.7+git freeradius-mysql=4:3.2.7+git freeradius-redis=4:3.2.7+git freeradius-rest=4:3.2.7+git freeradius-utils=4:3.2.7+git \
    && apt-get clean 

WORKDIR /usr/local/pf/

COPY lib lib

RUN mkdir -p /usr/local/pf/bin  && \
    mkdir -p /usr/local/pf/conf && \
    mkdir -p /usr/local/pf/logs

# Minimal configuration files needed to start freeradius

COPY ./conf/pf.conf.defaults /usr/local/pf/conf/pf.conf.defaults

RUN touch /usr/local/pf/conf/pf.conf /usr/local/pf/conf/pfconfig.conf

COPY ./conf/chi.conf.defaults /usr/local/pf/conf/chi.conf.defaults

COPY ./conf/chi.conf.example /usr/local/pf/conf/chi.conf

COPY ./conf/pfconfig.conf.defaults /usr/local/pf/conf/pfconfig.conf.defaults

COPY ./conf/log.conf.example /usr/local/pf/conf/log.conf

COPY ./bin/pflogger-packetfence /usr/local/pf/bin/pflogger-packetfence

COPY ./bin/pflogger.pl /usr/local/pf/bin/pflogger.pl

COPY ./config.mk /usr/local/pf/config.mk

RUN mkdir -p /usr/local/pf/var/run && \
    chown -R pf: /usr/local/pf/var

RUN chown -R pf: /usr/local/pf/logs && \
    chmod 664 -R /usr/local/pf/logs

RUN sed -i 's#^socket\s*=.*#socket=/var/lib/mysql/mysql.sock#' /etc/mysql/my.cnf

