ARG KNK_REGISTRY_URL
ARG IMAGE_TAG
FROM ${KNK_REGISTRY_URL}/pfdebian:${IMAGE_TAG}

RUN apt-get -qq update \
    && apt-get clean \
    && apt-get -qq install -y proxysql default-mysql-client \
    && apt-get clean

COPY bin/proxysql-read-only-handler.sh /proxysql-read-only-handler.sh
RUN chmod +x /proxysql-read-only-handler.sh
RUN mkdir -p /usr/local/pf/var/proxysql/

ENTRYPOINT ["proxysql", "-f", "-D", "/usr/local/pf/var/proxysql/", "-c", "/usr/local/pf/var/conf/proxysql.conf", "--initial", "--idle-threads"]
