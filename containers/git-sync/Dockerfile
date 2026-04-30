FROM debian:12 as builder
RUN apt update && apt -y install git-crypt


FROM registry.k8s.io/git-sync/git-sync:v4.2.4

USER 0:0

COPY --from=builder /usr/bin/git-crypt /usr/bin/
COPY --from=builder /usr/lib/x86_64-linux-gnu/libcrypto.so* /usr/lib/x86_64-linux-gnu/
COPY --from=builder /usr/lib/x86_64-linux-gnu/libstdc++.so* /usr/lib/x86_64-linux-gnu/
COPY --from=builder /usr/lib/x86_64-linux-gnu/libgcc_s.so* /usr/lib/x86_64-linux-gnu/

COPY containers/git-sync/pf-git-crypt-unlock /usr/local/bin/pf-git-crypt-unlock
RUN chmod a+x /usr/local/bin/pf-git-crypt-unlock

USER 65533:65533
