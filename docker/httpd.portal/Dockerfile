FROM pfdebian:11.3

WORKDIR /usr/local/pf/

COPY lib lib
COPY html html

ENTRYPOINT /usr/sbin/apache2 -f /usr/local/pf/var/conf/httpd.conf.d/httpd.portal -DFOREGROUND -Ddebian


