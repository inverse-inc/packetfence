ARG KNK_REGISTRY_URL
ARG IMAGE_TAG
FROM ${KNK_REGISTRY_URL}/radiusd:${IMAGE_TAG}

COPY bin/ntlm_auth_wrapper /usr/local/pf/bin/

ENTRYPOINT /usr/sbin/freeradius -d /usr/local/pf/raddb -n cli -fm -lstdout
