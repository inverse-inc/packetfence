ARG KNK_REGISTRY_URL
ARG IMAGE_TAG
FROM ${KNK_REGISTRY_URL}/radiusd:${IMAGE_TAG}

RUN apt update && apt install -y packetfence-ntlm-wrapper

ENTRYPOINT /usr/sbin/freeradius -d /usr/local/pf/raddb -n cli -fm -lstdout
