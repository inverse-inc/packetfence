ARG KNK_REGISTRY_URL
ARG IMAGE_TAG
FROM ${KNK_REGISTRY_URL}/pfdebian:${IMAGE_TAG}

RUN apt update && apt install fingerbank --reinstall

FROM alpine:3.21.2

ARG FINGERBANK_BUILD_API_KEY

RUN apk update && apk add curl sqlite

RUN mkdir -p /usr/local/fingerbank/db

COPY --from=0 /usr/local/fingerbank/db/fingerbank_Local.db /usr/local/fingerbank/db/fingerbank_Local.db

RUN curl --fail --retry 3 -H "Authorization: Bearer ${FINGERBANK_BUILD_API_KEY}" https://api.fingerbank.org/api/v2/download/db > /usr/local/fingerbank/db/fingerbank_Upstream.db

# Delete the unknown MAC vendors, they aren't useful in this image (meant to be used for the SaaS)
RUN sqlite3 /usr/local/fingerbank/db/fingerbank_Upstream.db "delete from mac_vendor where name like 'Unknown%';"
RUN sqlite3 /usr/local/fingerbank/db/fingerbank_Upstream.db "VACUUM;"

