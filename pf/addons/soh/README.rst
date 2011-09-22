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

#. Put the CGI script and its dependencies in place:

   ln -sf $install_dir/addons/soh/soh.cgi $install_dir/html/admin/soh.cgi
   ln -sf $install_dir/addons/soh/templates/soh \
       $install_dir/html/captive-portal/templates/soh

#. Optional. Add rewrite rules for nicer URLs (/soh.cgi -> /soh) in the
   admin VirtualHost:

   RewriteRule ^/soh([^.]*)$ /soh.cgi$1 [PT]

#. Copy packetfence-soh.pm to /etc/raddb, and add the following section
   to /etc/raddb/modules/perl:

   perl sohperl {
       module = ${confdir}/packetfence-soh.pm
   }

#. Create a virtual server to handle SoH requests by placing the
   following into /etc/raddb/sites-enabled/soh-server:

   server soh-server {
       authorize {
           perl
           update config {
               Auth-Type = Accept
           }
       }
   }

#. Enable SoH support inside the peap {} section in eap.conf:

   soh = yes
   soh-virtual-server = "soh-server"

#. Install the core modules:

   ln -sf $install_dir/addons/soh/lib/pf/soh.pm \
       $install_dir/lib/pf/soh.pm
   ln -sf $install_dir/addons/soh/lib/pf/soh/custom.pm \
       $install_dir/lib/pf/soh/custom.pm

#. Make sure $install_dir/lib/pf/WebAPI.pm has an soh_authorize
   endpoint. XXX depends on how this is going to be installed XXX

Web interface
=============

...
