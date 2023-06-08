ARG RUBY_VERSION

FROM registry.gitlab.com/orange-opensource/gitlab-buildpkg/rockylinux:8

ENV PATH /usr/local/go/bin:$PATH

RUN yum install -y python3 @ruby:${RUBY_VERSION}
# Check if python3 is there
RUN [ ! -f /usr/bin/python ] && ln -s /usr/bin/python3 /usr/bin/python

RUN yum localinstall http://packetfence.org/downloads/PacketFence/RHEL8/packetfence-release-${PF_VERSION}.el8.noarch.rpm -y

RUN unf module install nodejs:12

RUN KTYPES=('asciidoctor' 'asciidoctor-pdf' 'rouge')

RUN for k in ${KTYPES[@]}; do \
    mkdir -p /usr/local/bin/${k} ; \
    gem install ${k} --no-user-install -n /usr/lolca/bin/ ; \
    done

COPY addons/dev-helpers/setup-dev-env.sh /usr/local/pf/addons/dev-helpers/setup-dev-env.sh
RUN bash /usr/local/pf/addons/dev-helpers/setup-dev-env.sh

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
