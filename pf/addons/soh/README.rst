===========================
SoH support for Packetfence
===========================

Introduction
============

This addon is used to parse and act upon statement-of-health ("SoH")
indications encapsulated in 802.1x authentication exchanges. These can
be used, for example, to deny network access to clients who do not have
an anti-virus program installed, or do not have the latest updates.

For more details about Microsoft NAP (the protocol used to transmit SoH
indications), see http://technet.microsoft.com/en-us/network/bb545879

Installation and configuration
==============================

1. Create the necessary tables:

   mysql pf < soh.sql

2. Put the CGI script and its dependencies in place:

   ln -sf $install_dir/addons/soh/soh.cgi $install_dir/html/admin/soh.cgi
   ln -sf $install_dir/addons/soh/templates/soh \
       $install_dir/html/captive-portal/templates/soh

3. Optional. Add rewrite rules for nicer URLs (/soh.cgi -> /soh) in the
   admin VirtualHost:

   RewriteRule ^/soh([^.]*)$ /soh.cgi$1 [PT]

Web interface
=============

...
