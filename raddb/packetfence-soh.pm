#!/usr/bin/perl

=head1 NAME

packetfence-soh.pm - FreeRADIUS PacketFence integration module for SoH support

=head1 DESCRIPTION

This module forwards SoH authorization requests to PacketFence.

=head1 NOTES

Note1:

Our pf::config package is loading all kind of stuff and should be reworked a bit. We need to use that package to load
configuration parameters from the configuration file. Until the package is cleaned, we will define the configuration
parameter here.

Once cleaned:

- Uncommented line: use pf::config

- Remove line: use constant SOAP_PORT => '9090';

- Remove line: $curl->setopt(CURLOPT_URL, 'http://127.0.0.1:' . SOAP_PORT);

- Uncomment line: $curl->setopt(CURLOPT_URL, 'http://127.0.0.1:' . $Config{'ports'}{'soap'});

Search for 'note1' to find the appropriate lines.

=cut

use strict;
use warnings;


use lib '/usr/local/pf/lib/';

#use pf::config; # TODO: See note1
use pf::radius::constants;
# Configuration parameter
use constant RPC_PORT_KEY   => 'PacketFence-RPC-Port';
use constant RPC_SERVER_KEY => 'PacketFence-RPC-Server';
use constant RPC_PROTO_KEY  => 'PacketFence-RPC-Proto';
use constant RPC_USER_KEY   => 'PacketFence-RPC-User';
use constant RPC_PASS_KEY   => 'PacketFence-RPC-Pass';
use constant DEFAULT_RPC_SERVER => '127.0.0.1';
use constant DEFAULT_RPC_PORT   => '7070';
use constant DEFAULT_RPC_PROTO  => 'http';
use constant DEFAULT_RPC_USER   => undef;
use constant DEFAULT_RPC_PASS   => undef;
use pf::radius::rpc;


require 5.8.8;

# This is very important! Without this, the script will not get the filled hashes from FreeRADIUS.
our (%RAD_REQUEST, %RAD_REPLY, %RAD_CHECK, %RAD_CONFIG);


=head1 SUBROUTINES

=over

=item * _get_rpc_config

get the rpc configuration

=cut

sub _get_rpc_config {
    return {
        server => $RAD_CONFIG{RPC_SERVER_KEY()} || DEFAULT_RPC_SERVER,
        port   => $RAD_CONFIG{RPC_PORT_KEY()}   || DEFAULT_RPC_PORT,
        proto  => $RAD_CONFIG{RPC_PROTO_KEY()}  || DEFAULT_RPC_PROTO,
        user   => $RAD_CONFIG{RPC_USER_KEY()}   || DEFAULT_RPC_USER,
        pass   => $RAD_CONFIG{RPC_PASS_KEY()}   || DEFAULT_RPC_PASS,
    };
}

=item * authorize

This function is called to evaluate and react to an SoH packet. It is
the only callback available inside an SoH virtual server.

=cut

sub authorize {
    my $radius_return_code = $RADIUS::RLM_MODULE_REJECT;
    eval {
        my $config = _get_rpc_config();
        my $data = send_rpc_request($config, "soh_authorize", \%RAD_REQUEST);
        if ($data) {

            my $elements = $data->[0];

            $elements = [$elements] unless ref($elements) eq 'ARRAY';
            # Get RADIUS SoH return code
            $radius_return_code = shift @$elements;

            if ( !defined($radius_return_code) || !($radius_return_code > $RADIUS::RLM_MODULE_REJECT && $radius_return_code < $RADIUS::RLM_MODULE_NUMCODES) ) {
                return $RADIUS::RLM_MODULE_FAIL;
            }
        } else {
            return $RADIUS::RLM_MODULE_FAIL;
        }

        &radiusd::radlog($RADIUS::L_DBG, "StatementOfHealth RESULT RESPONSE CODE: $radius_return_code (2 means OK)");

        # Uncomment for verbose debugging with radius -X
        # Warning: This is a native module so you shouldn't run it with radiusd in threaded mode (default)
        # use Data::Dumper;
        # $Data::Dumper::Terse = 1; $Data::Dumper::Indent = 0; # pretty output for rad logs
        # &radiusd::radlog($RADIUS::L_DBG, "StatementOfHealth COMPLETE REPLY: ". Dumper(\%RAD_REPLY));
    };
    if ($@) {
        &radiusd::radlog($RADIUS::L_ERR, "An error occurred while processing the SoH authorize SOAP request: $@");
    }

    return $radius_return_code;
}


=back

=head1 SEE ALSO

L<http://wiki.freeradius.org/Rlm_perl>

=head1 COPYRIGHT

Copyright (C) 2005-2015 Inverse inc.

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
