ARG KNK_REGISTRY
ARG IMAGE_TAG
FROM ${KNK_REGISTRY}/pfdebian:${IMAGE_TAG}

WORKDIR /usr/local/pf/

RUN mkdir -p /usr/local/pf/var/control/
RUN mkdir -p /usr/local/pf/var/run/

COPY lib lib
COPY sbin/pfconfig sbin/pfconfig

ENTRYPOINT /usr/local/pf/sbin/pfconfig

