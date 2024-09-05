FROM proxysql/proxysql:2.6.0-debian

RUN apt-get update && apt-get install -y jq

COPY bin/proxysql-read-only-handler.sh /proxysql-read-only-handler.sh
RUN chmod +x /proxysql-read-only-handler.sh
RUN mkdir -p /usr/local/pf/var/proxysql/

ENTRYPOINT ["proxysql", "-f", "-D", "/usr/local/pf/var/proxysql/", "-c", "/usr/local/pf/var/conf/proxysql.conf", "--initial", "--idle-threads"]
