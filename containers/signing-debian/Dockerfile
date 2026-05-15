FROM debian:bookworm

ENV DEBIAN_FRONTEND=noninteractive

# dpkg-sig was removed from Debian 12 (bookworm) and is not in bookworm-backports.
# The bullseye package is Architecture: all (pure Perl) and its runtime deps
# (perl, gnupg, libdigest-md5-perl, libconfig-file-perl) are all in bookworm,
# so we fetch the .deb from the Debian archive and let apt resolve its deps.
ARG DPKG_SIG_DEB_URL=https://archive.debian.org/debian/pool/main/d/dpkg-sig/dpkg-sig_0.13.1+nmu4_all.deb

# Pre-bake all signing/upload/publish dependencies; no runtime apt-get install.
RUN apt-get update -qq && apt-get install -y --no-install-recommends \
        curl ca-certificates gnupg && \
    curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg \
        | gpg --dearmor -o /usr/share/keyrings/githubcli-archive-keyring.gpg && \
    chmod go+r /usr/share/keyrings/githubcli-archive-keyring.gpg && \
    echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" \
        > /etc/apt/sources.list.d/github-cli.list && \
    curl -fsSL "${DPKG_SIG_DEB_URL}" -o /tmp/dpkg-sig.deb && \
    apt-get update -qq && apt-get install -y --no-install-recommends \
        gh \
        gpg \
        python3 python3-nacl python3-requests \
        openssh-client rsync \
        build-essential \
        dpkg-dev debhelper \
        wget sudo \
        /tmp/dpkg-sig.deb && \
    rm -f /tmp/dpkg-sig.deb && \
    rm -rf /var/lib/apt/lists/*
