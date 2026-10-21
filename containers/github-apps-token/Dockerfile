FROM debian:12.12-slim

# Switch to root to install packages
USER 0:0

# Install Python 3, pip, curl, and other dependencies
RUN apt-get update && \
    apt-get install -y \
    python3 \
    python3-pip \
    curl \
    ca-certificates \
    apt-transport-https \
    && apt-get clean && \
    rm -rf /var/lib/apt/lists/*

# Install kubectl
RUN curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl" && \
    chmod +x kubectl && \
    mv kubectl /usr/local/bin/ && \
    apt-get remove -y curl apt-transport-https && \
    apt-get autoremove -y && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*

# Verify installations
RUN kubectl version --client && python3 --version

COPY ./containers/github-apps-token/requirements.txt /root/requirements.txt
COPY ./containers/github-apps-token/token_github_apps.py /usr/local/bin/token_github_apps.py

# Install Python dependencies
RUN pip3 install --no-cache-dir --break-system-packages -r /root/requirements.txt


# Create non-root user
ENTRYPOINT [ "python3", "/usr/local/bin/token_github_apps.py" ]

USER 65533:65533
