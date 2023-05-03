ARG KNK_REGISTRY_URL
ARG IMAGE_TAG
FROM ${KNK_REGISTRY_URL}/pfdebian:${IMAGE_TAG}

ENV DEBIAN_FRONTEND=noninteractive
RUN apt-get update && \
  apt-get install -y gcc python-dev libkrb5-dev && \
  apt-get install python3-pip -y && \
  pip3 install --upgrade pip && \
  pip3 install --upgrade virtualenv && \
  pip3 install pywinrm[kerberos] && \
  apt install krb5-user -y && \ 
  pip3 install pywinrm && \
  pip3 install ansible

RUN ansible-galaxy install arubanetworks.aoscx_role
RUN ansible-galaxy collection install cisco.ios
RUN ansible-galaxy collection install community.network
RUN ansible-galaxy collection install cisco.asa
