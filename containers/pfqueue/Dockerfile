ARG KNK_REGISTRY_URL
ARG IMAGE_TAG
FROM ${KNK_REGISTRY_URL}/pfdebian:${IMAGE_TAG}

WORKDIR /usr/local/pf/

RUN mkdir -p /usr/local/pf/var/run/

COPY lib lib
COPY sbin/pfqueue sbin/pfqueue

COPY html/captive-portal/templates html/captive-portal/templates

ENTRYPOINT /usr/local/pf/sbin/pfqueue
