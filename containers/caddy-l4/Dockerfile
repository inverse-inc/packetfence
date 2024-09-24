FROM caddy:2

ARG go_version=23.1

RUN wget https://golang.org/dl/go1."${go_version}".linux-amd64.tar.gz

RUN tar -C /usr/local -xzf go1."${go_version}".linux-amd64.tar.gz && rm -rf go1."${go_version}".linux-amd64.tar.gz 

ENV PATH="$PATH:/usr/local/go/bin"

RUN go version && go install github.com/caddyserver/xcaddy/cmd/xcaddy@latest  

ENV PATH="$PATH:/root/go/bin/"

RUN xcaddy build --with github.com/mholt/caddy-l4

RUN old_bin_file=$(which caddy) && rm -rf $old_bin_file

ENV PATH="$PATH:/srv"
