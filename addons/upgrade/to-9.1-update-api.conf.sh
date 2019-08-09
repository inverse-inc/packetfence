#!/bin/bash

perl -pi -e's/127.0.0.1:8080/127.0.0.1:22224/' /usr/local/pf/conf/caddy-services/api.conf
