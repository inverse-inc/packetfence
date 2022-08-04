ARG KNK_REGISTRY_URL
ARG IMAGE_TAG
FROM ${KNK_REGISTRY_URL}/pfdebian:${IMAGE_TAG}
WORKDIR /usr/local/pf/
RUN mkdir -p /usr/local/pf/var/run/
COPY html/pfappserver/root/errors/ html/pfappserver/root/errors/

RUN apt-get update -y && \
    apt-get install -y \
            haproxy \
            inotify-tools \
            runit

ENTRYPOINT /usr/sbin/haproxy -Ws -f /usr/local/pf/var/conf/haproxy-admin.conf -p /usr/local/pf/var/run/haproxy-admin.pid
