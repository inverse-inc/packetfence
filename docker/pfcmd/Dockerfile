FROM pfdebian:11.3

WORKDIR /usr/local/pf/

RUN mkdir -p /usr/local/pf/var/control/
RUN mkdir -p /usr/local/pf/var/run/

COPY lib lib
COPY bin/pfcmd.pl bin/pfcmd.pl

RUN ln -s /usr/local/pf/bin/pfcmd.pl /usr/local/pf/bin/pfcmd

ENTRYPOINT /usr/local/pf/bin/pfcmd


