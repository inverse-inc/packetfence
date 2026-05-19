ARG KNK_REGISTRY_URL
ARG IMAGE_TAG
FROM ${KNK_REGISTRY_URL}/pfdebian:${IMAGE_TAG}

WORKDIR /usr/local/pf/

COPY ./html ./html
COPY ./lib ./lib
COPY ./db ./db
COPY ./sbin/pfperl-api ./sbin/pfperl-api
COPY ./bin/impacket ./bin/impacket
COPY ./bin/pfcmd.pl ./bin/pfcmd.pl
COPY ./addons/ntlm-auth-api/openssl.cnf /etc/ssl/openssl.cnf

RUN ln -s /usr/local/pf/bin/pfcmd.pl /usr/local/pf/bin/pfcmd && \
    ln -s /usr/local/pf/bin/impacket/impacket_addcomputer.py /usr/local/pf/bin/impacket-addcomputer && \
    chmod 0755 /usr/local/pf/bin/impacket/impacket_addcomputer.py && \
    mkdir -p   ./var/run/  && \
    chmod 0744 ./var/run/  && \
    mkdir -p ./var/control && \
    bash -c 'cd /usr/local/pf/db && export VERSIONSQL=$(ls pf-schema-* |sort --version-sort -r | head -1) && ln -f -s $VERSIONSQL ./pf-schema.sql'

ENTRYPOINT ["/usr/local/pf/sbin/pfperl-api", "prefork", "-m", "production", "-l", "http://127.0.0.1:22224", "-l", "http://100.64.0.1:22224", "--pid-file", "/usr/local/pf/var/run/pfperl-api.pid"]
