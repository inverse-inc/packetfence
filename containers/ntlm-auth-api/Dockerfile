ARG KNK_REGISTRY_URL
ARG IMAGE_TAG
FROM ${KNK_REGISTRY_URL}/pfdebian:${IMAGE_TAG}

WORKDIR /usr/local/pf/

COPY bin bin

RUN apt-get -qq update && \
    apt-get -yqq install python3-pip python3-pymysql python3-sdnotify python3-tz python3-dev gunicorn3 python3-psutil

RUN VER=`python3 -c 'import sys; val=sys.version_info;print(str(val.major)+"."+str(val.minor))'` ; \
    sudo rm -rf /usr/lib/python$VER/EXTERNALLY-MANAGED && \
    pip3 install flask-mysql==1.5.2

COPY addons/ntlm-auth-api/openssl.cnf /usr/lib/ssl/openssl.cnf

ENTRYPOINT /usr/bin/gunicorn -c /usr/local/pf/bin/pyntlm_auth/gunicorn.conf.py
