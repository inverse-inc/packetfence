FROM python:3.12-slim

WORKDIR /app

# The test tools. eapol_test is NOT in wpasupplicant on Debian -- it is its own
# package, eapoltest (bookworm+); radclient in
# freeradius-utils, plus tcpdump/tshark for capture. These used to be installed
# on the host and reached over a mounted socket; keeping them in the image means
# a PacketFence upgrade cannot change their versions underneath us.
# DEBIAN_FRONTEND stops tshark's prompt about non-root capture hanging the build.
ENV DEBIAN_FRONTEND=noninteractive
RUN apt-get update \
 && apt-get install -y --no-install-recommends wpasupplicant freeradius-utils tcpdump tshark libcap2-bin tini util-linux iproute2 \
 && (apt-get install -y --no-install-recommends eapoltest \
     || echo '  NOTE: eapoltest package unavailable; 802.1X tests will be off') \
 && rm -rf /var/lib/apt/lists/*

# Dependencies first (better layer caching)
COPY containers/pfchatbot/requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# App
COPY lib/pfchatbot/app.py .
COPY html/pfchatbot/ ./static/
COPY lib/pfchatbot/store.py .
COPY lib/pfchatbot/prompts.py .
COPY lib/pfchatbot/tools.py .
COPY lib/pfchatbot/providers/ ./providers/
COPY lib/pfchatbot/rag/ ./rag/
COPY lib/pfchatbot/pf-testtool-helper.py .
COPY containers/pfchatbot/supervisor.sh .

# Two identities, because the helper is the only thing allowed to execute the
# RADIUS tools. The app runs as pfbot and is NOT in the pfhelper group, so even
# if the application process were compromised it cannot exec them directly -- it
# must go through the helper's validated command set, exactly as when the helper
# lived in its own systemd unit.
RUN useradd -r -u 10001 -m -d /home/pfbot pfbot \
 && useradd -r -u 10002 -M -d /nonexistent -s /usr/sbin/nologin pfhelper \
 && mkdir -p /home/pfbot/.cache \
 && chown -R pfbot /app /home/pfbot \
 && chmod 0755 /app/supervisor.sh \
 && test -s /app/supervisor.sh \
 && sh -n /app/supervisor.sh \
 && sed -i 's/\r$//' /app/supervisor.sh

# Lock the RADIUS tools to the helper identity. Paths differ between releases,
# so locate them rather than assume; and report at BUILD time if one is absent
# instead of failing mysteriously when someone clicks Run test.
#
# NOTE: Debian's wpasupplicant does not always ship eapol_test -- it is a test
# binary built from the wpa_supplicant source. If the build prints MISSING for
# it, copy the host's binary into the image (see README) or the 802.1X tests
# will be unavailable while radclient/radtest keep working.
RUN set -eu; \
    for b in eapol_test radclient radtest tcpdump tshark dumpcap; do \
      p="$(command -v "$b" 2>/dev/null || true)"; \
      if [ -n "$p" ]; then \
        chown root:pfhelper "$p" && chmod 0750 "$p"; \
        echo "  tool $b -> $p (root:pfhelper 0750)"; \
      else \
        echo "  tool $b -> MISSING"; \
      fi; \
    done; \
    # Capture needs CAP_NET_RAW (raw sockets) and CAP_NET_ADMIN (promiscuous
    # mode). The container is started with exactly those two in its bounding
    # set; the file capability is what lets the non-root pfhelper user use them.
    # pfbot has no path to this: the binary is root:pfhelper 0750.
    for b in tcpdump dumpcap; do \
      p="$(command -v "$b" 2>/dev/null || true)"; \
      [ -n "$p" ] && setcap cap_net_raw,cap_net_admin+eip "$p" && \
        echo "  setcap cap_net_raw,cap_net_admin -> $p" || true; \
    done

ENV HOME=/home/pfbot \
    PF_TESTTOOL_SOCK=/run/pf-testtool/helper.sock \
    PYTHONUNBUFFERED=1

# BIND_HOST is resolved by supervisor.sh at run time: "auto" picks the
# PacketFence management IP, then 100.64.0.1, then 127.0.0.1 -- never 0.0.0.0.
# Override it in .env to pin an address.
ENV BIND_HOST=auto \
    BIND_PORT=8800

EXPOSE 8800

# tini reaps the two children and forwards SIGTERM so both shut down cleanly
ENTRYPOINT ["/usr/bin/tini", "--"]
CMD ["/bin/sh", "/app/supervisor.sh"]
