FROM debian:bookworm

ENV DEBIAN_FRONTEND=noninteractive

# Pre-bake all signing/upload/publish dependencies; no runtime apt-get install.
RUN apt-get update -qq && apt-get install -y --no-install-recommends \
        curl ca-certificates gnupg && \
    curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg \
        | gpg --dearmor -o /usr/share/keyrings/githubcli-archive-keyring.gpg && \
    chmod go+r /usr/share/keyrings/githubcli-archive-keyring.gpg && \
    echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" \
        > /etc/apt/sources.list.d/github-cli.list && \
    apt-get update -qq && apt-get install -y --no-install-recommends \
        gh \
        gpg dpkg-sig \
        python3 python3-nacl python3-requests \
        openssh-client rsync \
        build-essential \
        dpkg-dev debhelper \
        wget sudo && \
    rm -rf /var/lib/apt/lists/*
