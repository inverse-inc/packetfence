ARG KNK_REGISTRY_URL
ARG IMAGE_TAG
FROM ${KNK_REGISTRY_URL}/pfdebian:${IMAGE_TAG}

WORKDIR /usr/local/pf/
COPY bin bin
RUN apt-get update
RUN apt-get -y install python3-pip python3-pymysql python3-sdnotify python3-tz
RUN pip3 install flask-mysql==1.5.2

ENTRYPOINT /usr/bin/python3 /usr/local/pf/bin/pyntlm_auth/app.py
