FROM haproxy:2.2.22

RUN mkdir -p /usr/local/pf/var/run

ENTRYPOINT ["/docker-entrypoint.sh"]
CMD ["haproxy", "-f", "/usr/local/pf/var/conf/haproxy-portal.conf", "-p", "/usr/local/pf/var/run/haproxy-portal.pid"]