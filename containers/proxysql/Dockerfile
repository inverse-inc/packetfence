ARG from=debian:bullseye
ARG KNK_REGISTRY_URL
ARG IMAGE_TAG

FROM ${from} as build

ARG DEBIAN_FRONTEND=noninteractive

LABEL vendor=proxysql\
      com.proxysql.type=proxysql\
      com.proxysql.os=debian11\
      com.proxysql.interactive=false\
      com.proxysql.config=simple\
      com.proxysql.purpose=production

RUN apt-get update && apt-get install -y \
        automake \
        cmake \
        make \
        g++ \
        gcc \
        gdb \
        gdbserver \
        git \
        libgnutls28-dev \
        libmariadb-dev \
        libssl-dev \
        libtool \
        gawk \
        bzip2 \
        python3 \
        uuid-dev \
        libsystemd-dev \
        systemd \
  && \
  apt-get clean && \
  rm -rf /var/lib/apt/lists/

#
#  Create build directory
#
RUN mkdir -p /usr/local/src/repositories
WORKDIR /usr/local/src/repositories

#
#  Shallow clone the proxysql source
#
ARG source=https://github.com/fdurand/proxysql.git
ARG release=sd_notify

RUN git clone -qq --depth 1 --single-branch --branch ${release} ${source}
WORKDIR proxysql

#
#  Build the server
#
RUN make clean && make && make install

ENTRYPOINT ["proxysql", "-f", "-D", "/usr/local/pf/var/proxysql/", "-c", "/usr/local/pf/var/conf/proxysql.conf", "--initial", "--idle-threads"]
