FROM golang:1.17
RUN mkdir -p /usr/local/pf/
WORKDIR /usr/local/pf/
COPY ./go /usr/local/pf/go
COPY ./lib /usr/local/pf/lib
COPY ./config.mk /usr/local/pf/config.mk
RUN cd /usr/local/pf/go/ &&  make pfdhcp
RUN cd /usr/local/pf/go/ &&  make pfdns
RUN cd /usr/local/pf/go/ &&  make pfhttpd
RUN cd /usr/local/pf/go/ &&  make pfstats

FROM debian
RUN mkdir -p /usr/local/pf/
WORKDIR /usr/local/pf/
COPY --from=0 /usr/local/pf/go/pfdhcp /usr/local/pf/pfdhcp
COPY --from=0 /usr/local/pf/go/pfdns /usr/local/pf/pfdns
COPY --from=0 /usr/local/pf/go/pfhttpd /usr/local/pf/pfhttpd
COPY --from=0 /usr/local/pf/go/pfstats /usr/local/pf/pfstats
