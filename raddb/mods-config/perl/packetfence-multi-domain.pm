#!/usr/bin/perl

=head1 NAME

packetfence-multi-domain.pm - FreeRADIUS PacketFence multi domain integration module

=head1 DESCRIPTION

This module finds the Domain to use from the Realm defined in FreeRADIUS

=head1 NOTES

Note1:

Our pf::config package loads all the earth.
This code is executed both in the PacketFence and PacketFence tunnel in FreeRADIUS
We need access to the ConfigDomain hash so either we should go though the the ConfigStore directly or find a better way to load it's configuration

=cut

use strict;
use warnings;


use lib '/usr/local/pf/lib/';

use pf::log (service => 'rlm_perl');
use pf::radius::constants;
use pf::radius::soapclient;
use pf::radius::rpc;
use pf::util::freeradius qw(clean_mac);
use pfconfig::cached_hash;
use pf::util::statsd qw(called);
use pf::StatsD::Timer;
use pf::config::tenant;
tie our %ConfigRealm, 'pfconfig::cached_hash', 'config::Realm', tenant_id_scoped => 1;

require 5.8.8;

# This is very important! Without this, the script will not get the filled hashes from FreeRADIUS.
our (%RAD_REQUEST, %RAD_REPLY, %RAD_CHECK, %RAD_CONFIG);

=head1 SUBROUTINES

=over

=item * authorize

RADIUS calls this method to authorize clients.

=cut

sub authorize {
    my $timer = pf::StatsD::Timer->new({ sample_rate => 0.05, 'stat' => "freeradius::" . called() });
    pf::config::tenant::set_tenant($RAD_CONFIG{'PacketFence-Tenant-Id'});
    # For debugging purposes only
    #&log_request_attributes;

    # We try to find the realm that's configured in PacketFence
    my $realm_config;
    my $user_name = $RAD_REQUEST{'TLS-Client-Cert-Common-Name'} || $RAD_REQUEST{'User-Name'};
    if ($user_name =~ /^host\/([0-9a-zA-Z-_]+)\.(.*)$/) {
        $realm_config = $ConfigRealm{lc($2)};
    } elsif (defined $RAD_REQUEST{"Realm"}) {
        $realm_config = $ConfigRealm{$RAD_REQUEST{"Realm"}};
    }

    if ( !defined($realm_config) && defined($ConfigRealm{"default"}) ) {
        $realm_config = $ConfigRealm{"default"};
    }

    #use Data::Dumper;
    #&radiusd::radlog($RADIUS::L_INFO, Dumper($realm));

    if( defined($realm_config) && defined($realm_config->{domain}) ) {
        # We have found this realm in PacketFence. We use the domain associated with it for the authentication
        $RAD_REQUEST{"PacketFence-Domain"} = $realm_config->{domain};
    }

    # If it doesn't go into any of the conditions above, then the behavior will be the same as before (non chrooted ntlm_auth)
    return $RADIUS::RLM_MODULE_UPDATED;
}

sub log_request_attributes {
        # This shouldn't be done in production environments!
        # This is only meant for debugging!
        for (keys %RAD_REQUEST) {
                &radiusd::radlog($RADIUS::L_INFO, "RAD_REQUEST: $_ = $RAD_REQUEST{$_}");
        }
        for (keys %RAD_CONFIG) {
                &radiusd::radlog($RADIUS::L_INFO, "RAD_CONFIG: $_ = $RAD_CONFIG{$_}");
        }
        for (keys %RAD_CHECK) {
                &radiusd::radlog($RADIUS::L_INFO, "RAD_CHECK: $_ = $RAD_CHECK{$_}");
        }
}

=item * server_error_handler

Called whenever there is a server error beyond PacketFence's control (401, 404, 500)

If a customer wants to degrade gracefully, he should put some logic here to assign good VLANs in a degraded way. Two examples are provided commented in the file.

=cut

sub server_error_handler {
   # no need to log here as on_fault is already triggered
   return $RADIUS::RLM_MODULE_FAIL;

   # TODO provide complete examples
   # for example:
   # send an email
   # set vlan default according to $nas_ip
   # return $RADIUS::RLM_MODULE_OK

   # or to fail open:
   # return $RADIUS::RLM_MODULE_OK
}

=item * invalid_answer_handler

Called whenever an invalid answer is returned from the server

=cut

sub invalid_answer_handler {
    &radiusd::radlog($RADIUS::L_ERR, "No or invalid reply in RPC communication with server. Check server side logs for details.");
    &radiusd::radlog($RADIUS::L_DBG, "PacketFence UNDEFINED RESULT RESPONSE CODE");
    &radiusd::radlog($RADIUS::L_DBG, "PacketFence RESULT VLAN COULD NOT BE DETERMINED");
    return $RADIUS::RLM_MODULE_FAIL;
}



#
# --- Unused FreeRADIUS hooks ---
#
# Function to handle post_auth
sub post_auth {
}

# Function to handle authenticate
sub authenticate {

}

# Function to handle preacct
sub preacct {
        # For debugging purposes only
#       &log_request_attributes;

}

# Function to handle accounting
sub accounting {
}

# Function to handle checksimul
sub checksimul {
        # For debugging purposes only
#       &log_request_attributes;

}

# Function to handle pre_proxy
sub pre_proxy {
        # For debugging purposes only
#       &log_request_attributes;

}

# Function to handle post_proxy
sub post_proxy {
        # For debugging purposes only
#       &log_request_attributes;

}

# Function to handle xlat
sub xlat {
        # For debugging purposes only
#       &log_request_attributes;

}

# Function to handle detach
sub detach {
        # For debugging purposes only
#       &log_request_attributes;

        # Do some logging.
        &radiusd::radlog($RADIUS::L_DBG, "rlm_perl::Detaching. Reloading. Done.");
}


=back

=head1 SEE ALSO

L<http://wiki.freeradius.org/Rlm_perl>

=head1 COPYRIGHT

Copyright (C) 2005-2018 Inverse inc.

=head1 LICENSE

This program is free software: you can redistribute it and/or modify
it under the terms of the GNU General Public License as published by
the Free Software Foundation, either version 3 of the License, or
(at your option) any later version.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
GNU General Public License for more details.

You should have received a copy of the GNU General Public License
along with this program.  If not, see <http://www.gnu.org/licenses/>.

=cut

1;
