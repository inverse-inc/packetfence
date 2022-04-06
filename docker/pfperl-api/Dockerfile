ARG GO_VERSION
ARG KNK_REGISTRY_URL
ARG IMAGE_TAG
FROM ${KNK_REGISTRY_URL}/pfdebian:${IMAGE_TAG}
WORKDIR /usr/local/pf/
COPY ./html ./html
COPY ./lib ./lib
COPY ./lib_perl ./lib_perl
COPY ./sbin/pfperl-api ./sbin/pfperl-api
RUN mkdir -p /usr/local/pf/var/run/ && chmod 0744 /usr/local/pf/var/run/
ENTRYPOINT /usr/local/pf/sbin/pfperl-api prefork -m production -l http://127.0.0.1:22224 --pid-file /usr/local/pf/var/run/pfperl-api.pid 
