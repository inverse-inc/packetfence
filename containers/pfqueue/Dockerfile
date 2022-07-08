ARG KNK_REGISTRY_URL
ARG IMAGE_TAG
FROM ${KNK_REGISTRY_URL}/pfdebian:${IMAGE_TAG}

WORKDIR /usr/local/pf/

RUN mkdir -p /usr/local/pf/var/run/

COPY addons/create_chroot.sh addons/create_chroot.sh
COPY addons/AD addons/AD

COPY bin/pfcmd.pl bin/pfcmd.pl
RUN ln -s /usr/local/pf/bin/pfcmd.pl /usr/local/pf/bin/pfcmd
RUN chmod ug+s /usr/local/pf/bin/pfcmd

COPY lib lib
COPY sbin/pfqueue sbin/pfqueue

ENTRYPOINT /usr/local/pf/sbin/pfqueue
