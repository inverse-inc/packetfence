ARG KNK_REGISTRY_URL
ARG IMAGE_TAG
FROM ${KNK_REGISTRY_URL}/pfdebian:${IMAGE_TAG}

RUN apt update && apt install fingerbank --reinstall

FROM alpine

ARG FINGERBANK_BUILD_API_KEY

RUN apk update && apk add curl

RUN mkdir -p /usr/local/fingerbank/db

COPY --from=0 /usr/local/fingerbank/db/fingerbank_Local.db /usr/local/fingerbank/db/fingerbank_Local.db

RUN curl --fail --retry 3 -H "Authorization: Bearer ${FINGERBANK_BUILD_API_KEY}" https://api.fingerbank.org/api/v2/download/db > /usr/local/fingerbank/db/fingerbank_Upstream.db

