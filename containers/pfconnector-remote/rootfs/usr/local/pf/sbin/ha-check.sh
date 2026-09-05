#!/bin/bash
# keepalived track script: is the local FreeRADIUS answering? Uses the
# localhost-only status listener of the auth server (addons/pfconnector/conf/
# radiusd/auth.conf, client "admin"/adminsecret in sites-enabled/status).
# FreeRADIUS requires a Message-Authenticator in Status-Server packets and
# radclient sends nothing on an empty body, hence the attribute on stdin.
# Exit status 0 = healthy.
echo "Message-Authenticator = 0x00" | exec /usr/bin/radclient -q -r 1 -t 2 127.0.0.1:18121 status adminsecret
