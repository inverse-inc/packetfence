FROM alpine

ARG FINGERBANK_API_KEY

RUN apk update && apk add curl

RUN mkdir -p /usr/local/fingerbank/db

RUN curl -H "Authorization: Bearer ${FINGERBANK_API_KEY}" https://api.fingerbank.org/api/v2/download/db > /usr/local/fingerbank/db/fingerbank_Upstream.db

