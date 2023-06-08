FROM registry.gitlab.com/orange-opensource/gitlab-buildpkg/debian:bullseye

ENV PATH /usr/local/go/bin:$PATH

RUN apt-get update && apt-get install -y aptitude wget gnupg apt-transport-https

RUN /bin/bash -c "echo 'deb http://inverse.ca/downloads/PacketFence/debian/${PF_VERSION} bullseye bullseye' > /etc/apt/sources.list.d/packetfence_deps.list"
RUN wget -q -O - https://inverse.ca/downloads/GPG_PUBLIC_KEY | apt-key add -
RUN apt-get update


RUN KTYPES=('asciidoctor' 'asciidoctor-pdf' 'rouge')
RUN for k in ${KTYPES[@]}; do \
    mkdir -p /usr/local/bin/${k} ; \
    gem install ${k} --no-user-install -n /usr/lolca/bin/ ;
    done

COPY addons/dev-helpers/debian/install-pf-dependencies.sh /usr/local/pf/addons/dev-helpers/debian/install-pf-dependencies.sh
RUN /usr/local/pf/addons/dev-helpers/debian/install-pf-dependencies.sh && \
      rm -f /usr/local/fingerbank/db/fingerbank_*.db

RUN apt-get install -y freeradius-common

RUN useradd -U -r -d "/usr/local/pf" -s /bin/sh -c "PacketFence" -M pf

RUN mkdir -p /usr/local/pf/lib/
RUN ln -s /usr/local/fingerbank/lib/fingerbank /usr/local/pf/lib/fingerbank

RUN chown -R pf: /usr/local/pf

# To be removed
RUN apt-get install -y libcisco-accesslist-parser-perl libparse-eyapp-perl
