FROM debian:12 as builder
RUN apt update && apt -y install git-crypt gpg gpg-agent


FROM registry.k8s.io/git-sync/git-sync:v4.2.4

USER 0:0

COPY --from=builder /usr/bin/mawk /usr/bin/awk
COPY --from=builder /usr/bin/gpg /usr/bin/
COPY --from=builder /usr/bin/gpg-agent /usr/bin/
COPY --from=builder /usr/bin/git-crypt /usr/bin/
COPY --from=builder /usr/lib/x86_64-linux-gnu/libstdc++.so* /usr/lib/x86_64-linux-gnu/
COPY --from=builder /usr/lib/x86_64-linux-gnu/libgcrypt.so* /usr/lib/x86_64-linux-gnu/
COPY --from=builder /usr/lib/x86_64-linux-gnu/libsqlite3.so* /usr/lib/x86_64-linux-gnu/
COPY --from=builder /usr/lib/x86_64-linux-gnu/libgcc_s.so* /usr/lib/x86_64-linux-gnu/
COPY --from=builder /usr/lib/x86_64-linux-gnu/libreadline.so* /usr/lib/x86_64-linux-gnu/
COPY --from=builder /usr/lib/x86_64-linux-gnu/libnpth.so* /usr/lib/x86_64-linux-gnu/
COPY --from=builder /usr/lib/x86_64-linux-gnu/libassuan.so* /usr/lib/x86_64-linux-gnu/
COPY --from=builder /usr/lib/x86_64-linux-gnu/libgpg-error.so* /usr/lib/x86_64-linux-gnu/

COPY containers/git-sync/pf-git-crypt-unlock /usr/local/bin/pf-git-crypt-unlock
RUN chmod a+x /usr/local/bin/pf-git-crypt-unlock

USER 65533:65533

