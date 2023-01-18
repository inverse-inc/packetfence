FROM registry.k8s.io/git-sync/git-sync:v3.6.3

USER 0:0

RUN apt update && apt install git-crypt

COPY containers/git-sync/pf-git-crypt-unlock /usr/local/bin/pf-git-crypt-unlock
RUN chmod a+x /usr/local/bin/pf-git-crypt-unlock

USER 65533:65533

