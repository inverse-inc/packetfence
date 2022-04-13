FROM haproxy:2.2.22

RUN mkdir -p /usr/local/pf/html/captive-portal/templates/
COPY /usr/local/pf/html/captive-portal/templates/* /usr/local/pf/html/captive-portal/templates/

ENTRYPOINT ["/docker-entrypoint.sh"]
CMD ["haproxy", "-f", "/usr/local/pf/var/conf/haproxy-portal.conf"]
