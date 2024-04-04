FROM bitnami/kubectl:1.29-debian-11

USER 0:0

RUN apt update; apt install python3 python3-pip -y

COPY ./containers/github-apps-token/requests.txt /root/requests.txt
COPY ./containers/github-apps-token/token_github_apps.py /usr/local/bin/token_github_apps.py

RUN pip3 install -r /root/requests.txt

ENTRYPOINT [ "python3", "/usr/local/bin/token_github_apps.py" ]
USER 65533:65533