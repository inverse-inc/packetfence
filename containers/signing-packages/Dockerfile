FROM debian:13

ENV DEBIAN_FRONTEND=noninteractive

# dpkg-sig was removed after Debian 11 (bullseye) and is in neither bookworm nor
# trixie, backports included. The bullseye package is Architecture: all (pure
# Perl) and its runtime deps resolve on trixie: perl, gnupg and
# libconfig-file-perl are packaged, and libdigest-md5-perl -- which has not been
# a real package since Digest::MD5 moved into core perl -- is satisfied by
# perl's Provides. So we fetch the .deb from the Debian archive and let apt
# resolve its deps.
ARG DPKG_SIG_DEB_URL=https://archive.debian.org/debian/pool/main/d/dpkg-sig/dpkg-sig_0.13.1+nmu4_all.deb
# SHA256 pinned from the signed bullseye main Packages index (dpkg-sig 0.13.1+nmu4).
# The .deb is fetched over plain HTTPS, so verify the checksum before installing to
# guard against archive tampering / MITM. Update this if DPKG_SIG_DEB_URL changes.
ARG DPKG_SIG_DEB_SHA256=64a0898317de54f50bebead2867a921b9adb1c8588ff3e5113164ff87efbc609

# Unified signing container for both DEB and RPM packages.
# Pre-bake all signing/upload/publish dependencies; no runtime apt-get install.
RUN apt-get update -qq && apt-get install -y --no-install-recommends \
        curl ca-certificates gnupg && \
    curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg \
        | gpg --dearmor -o /usr/share/keyrings/githubcli-archive-keyring.gpg && \
    chmod go+r /usr/share/keyrings/githubcli-archive-keyring.gpg && \
    echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" \
        > /etc/apt/sources.list.d/github-cli.list && \
    curl -fsSL "${DPKG_SIG_DEB_URL}" -o /tmp/dpkg-sig.deb && \
    echo "${DPKG_SIG_DEB_SHA256}  /tmp/dpkg-sig.deb" | sha256sum -c - && \
    apt-get update -qq && apt-get install -y --no-install-recommends \
        gh \
        gpg \
        python3 python3-nacl python3-requests \
        openssh-client rsync \
        build-essential \
        dpkg-dev debhelper \
        rpm \
        wget sudo \
        /tmp/dpkg-sig.deb && \
    rm -f /tmp/dpkg-sig.deb && \
    rm -rf /var/lib/apt/lists/* && \
    # Configure rpm to use gpg for signing (Debian's rpm needs explicit config)
    mkdir -p /root && \
    echo '%__gpg /usr/bin/gpg' > /root/.rpmmacros && \
    echo '%_signature gpg' >> /root/.rpmmacros && \
    echo '%_gpg_name %{nil}' >> /root/.rpmmacros
