ARG KNK_REGISTRY_URL
ARG IMAGE_TAG
FROM ${KNK_REGISTRY_URL}/pfdebian:${IMAGE_TAG}

WORKDIR /usr/local/pf/

RUN mkdir -p /usr/local/pf/var/control/ && \
    mkdir -p /usr/local/pf/var/run/

COPY lib lib
COPY containers/environment.template containers/environment.template
COPY bin/pfcmd.pl bin/pfcmd.pl

RUN ln -s /usr/local/pf/bin/pfcmd.pl /usr/local/pf/bin/pfcmd

ENTRYPOINT /usr/local/pf/bin/pfcmd
