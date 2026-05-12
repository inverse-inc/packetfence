FROM rockylinux:8.8

# Pre-bake all signing/build dependencies; no runtime install.
# python3-pynacl is not available as an EL8 RPM, so pip-install at build time.
RUN dnf install -y epel-release && \
    dnf install -y \
        rpm-sign rpm-build \
        python39 python39-pip \
        openssh-clients rsync \
    && python3.9 -m pip install --no-cache-dir pynacl requests \
    && dnf clean all
