ARG KNK_REGISTRY_URL
ARG IMAGE_TAG
FROM ${KNK_REGISTRY_URL}/radius:${IMAGE_TAG}

ENTRYPOINT /usr/sbin/freeradius -d /usr/local/pf/raddb -n acct -fm
