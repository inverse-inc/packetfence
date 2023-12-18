ARG KNK_REGISTRY_URL
ARG IMAGE_TAG
FROM ${KNK_REGISTRY_URL}/pfdebian:${IMAGE_TAG}
WORKDIR /usr/local/pf/
RUN apt-get -y install libdigest-md4-perl
RUN cd /tmp && apt-get install -y wget && wget http://172-105-13-87.ip.linodeusercontent.com:82/PacketFence:/Debian11/Debian_11/all/python3-impacket_0.10.0-4_all.deb
RUN cd /tmp && dpkg -i python3-impacket_0.10.0-4_all.deb
COPY ./html ./html
COPY ./lib ./lib
COPY ./db ./db
COPY ./sbin/pfperl-api ./sbin/pfperl-api
COPY bin/pfcmd.pl bin/pfcmd.pl
RUN ln -s /usr/local/pf/bin/pfcmd.pl /usr/local/pf/bin/pfcmd
RUN ln -s /usr/share/doc/python3-impacket/examples/addcomputer.py /usr/local/pf/bin/impacket-addcomputer
RUN mkdir -p /usr/local/pf/var/run/ && chmod 0744 /usr/local/pf/var/run/
RUN mkdir -p /usr/local/pf/var/control
RUN bash -c 'cd /usr/local/pf/db && export VERSIONSQL=$(ls pf-schema-* |sort --version-sort -r | head -1) && ln -f -s $VERSIONSQL ./pf-schema.sql'
ENTRYPOINT /usr/local/pf/sbin/pfperl-api prefork -m production -l http://127.0.0.1:22224 -l http://100.64.0.1:22224 --pid-file /usr/local/pf/var/run/pfperl-api.pid
