ARG KNK_REGISTRY_URL
ARG IMAGE_TAG
ARG FINGERBANK_BUILD_API_KEY
FROM ${KNK_REGISTRY_URL}/pfdebian:${IMAGE_TAG}

RUN apt-get -qq update && \
    apt-get -qq install -y fingerbank --reinstall && \
    apt-get -qq install -y sqlite

RUN curl --fail --retry 3 -H "Authorization: Bearer ${FINGERBANK_BUILD_API_KEY}" https://api.fingerbank.org/api/v2/download/db > /usr/local/fingerbank/db/fingerbank_Upstream.db

# Delete the unknown MAC vendors, they aren't useful in this image (meant to be used for the SaaS)
RUN sqlite3 /usr/local/fingerbank/db/fingerbank_Upstream.db "delete from mac_vendor where name like 'Unknown%';"
RUN sqlite3 /usr/local/fingerbank/db/fingerbank_Upstream.db "VACUUM;"
