FROM gcr.io/kaniko-project/executor:debug

COPY containers/kanikobuild /bin/kanikobuild
RUN chmod +x /bin/kanikobuild

ENTRYPOINT /bin/kanikobuild
