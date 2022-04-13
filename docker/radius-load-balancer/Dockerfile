ARG KNK_REGISTRY_URL
ARG IMAGE_TAG
FROM ${KNK_REGISTRY_URL}/radius:${IMAGE_TAG}

RUN apt-get update
RUN apt-get install -y supervisor

ADD docker/radius-load-balancer/supervisord.conf /etc/supervisor/conf.d/supervisord.conf

ENTRYPOINT ["/usr/bin/supervisord"]
