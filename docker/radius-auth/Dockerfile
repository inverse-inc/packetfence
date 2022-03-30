ARG from=radius
FROM ${from} as build

ENTRYPOINT /usr/sbin/freeradius -d /usr/local/pf/raddb -n auth -fm
