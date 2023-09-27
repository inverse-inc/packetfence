ARG KNK_REGISTRY_URL
ARG IMAGE_TAG
FROM ${KNK_REGISTRY_URL}/radiusd:${IMAGE_TAG}

RUN apt update && apt install -y packetfence-ntlm-wrapper

RUN mkdir -p /usr/local/pf/sbin/
COPY sbin/signal-proxy /usr/local/pf/sbin/signal-proxy
RUN chmod +x /usr/local/pf/sbin/signal-proxy

ENTRYPOINT timedatectl set-timezone $TIMEZONE;/usr/local/pf/sbin/signal-proxy --timeout 20 "/usr/sbin/freeradius -d /usr/local/pf/raddb -n auth -fm -lstdout"
