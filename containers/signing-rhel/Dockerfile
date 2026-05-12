FROM rockylinux:8.8

# Pre-bake all signing/build dependencies; no runtime install.
# python3-pynacl is not available as an EL8 RPM, so pip-install at build time.
# gcc + python39-devel + libffi-devel are needed because pynacl has a native
# extension and not every PyPI wheel rotation guarantees a manylinux build.
RUN dnf install -y epel-release && \
    dnf install -y \
        rpm-sign rpm-build \
        python39 python39-pip python39-devel \
        gcc libffi-devel \
        openssh-clients rsync \
    && python3.9 -m pip install --no-cache-dir pynacl requests \
    && dnf clean all
