ARG KNK_REGISTRY_URL
ARG IMAGE_TAG
FROM ${KNK_REGISTRY_URL}/pfdebian:${IMAGE_TAG}
WORKDIR /usr/local/pf/
COPY ./html ./html
COPY ./lib ./lib
COPY ./db ./db
COPY ./sbin/pfperl-api ./sbin/pfperl-api
COPY ./bin/pfcmd ./bin/pfcmd
COPY ./bin/pfcmd.pl ./bin/pfcmd.pl
RUN mkdir -p /usr/local/pf/var/run/ && chmod 0744 /usr/local/pf/var/run/
RUN mkdir -p /usr/local/pf/var/control
RUN bash -c 'cd /usr/local/pf/db && export VERSIONSQL=$(ls pf-schema-* |sort --version-sort -r | head -1) && ln -f -s $VERSIONSQL ./pf-schema.sql'
ENTRYPOINT /usr/local/pf/sbin/pfperl-api prefork -m production -l http://127.0.0.1:22224 -l http://100.64.0.1:22224 --pid-file /usr/local/pf/var/run/pfperl-api.pid
