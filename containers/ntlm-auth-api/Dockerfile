ARG KNK_REGISTRY_URL
ARG IMAGE_TAG
FROM ${KNK_REGISTRY_URL}/pfdebian:${IMAGE_TAG}

WORKDIR /usr/local/pf/
COPY bin bin

ENTRYPOINT /usr/bin/python3 /usr/local/pf/bin/pyntlm_auth/app.py

