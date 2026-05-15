FROM debian:bookworm-slim

# CI-only wrapper image for ci/lib/build/generate-material.sh.
# pfconfig daemon stays in its own sidecar, spawned by the script.

RUN apt-get update -qq && \
    apt-get install -y --no-install-recommends \
        ca-certificates curl gnupg \
        python3 python3-nacl \
        git make \
        bsdextrautils \
        openssh-client && \
    \
    install -m 0755 -d /etc/apt/keyrings && \
    curl -fsSL https://download.docker.com/linux/debian/gpg \
        -o /etc/apt/keyrings/docker.asc && \
    chmod a+r /etc/apt/keyrings/docker.asc && \
    echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/debian bookworm stable" \
        > /etc/apt/sources.list.d/docker.list && \
    \
    curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg \
        | gpg --dearmor -o /usr/share/keyrings/githubcli-archive-keyring.gpg && \
    chmod go+r /usr/share/keyrings/githubcli-archive-keyring.gpg && \
    echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" \
        > /etc/apt/sources.list.d/github-cli.list && \
    \
    apt-get update -qq && \
    apt-get install -y --no-install-recommends \
        docker-ce-cli \
        gh && \
    rm -rf /var/lib/apt/lists/*

ENTRYPOINT []
