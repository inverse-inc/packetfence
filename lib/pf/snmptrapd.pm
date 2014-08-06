package pf::snmptrapd;
=head1 NAME

pfsnmptrapd add documentation

=cut

=head1 DESCRIPTION

pfsnmptrapd

=cut

use strict;
use warnings;
use lib qw(/usr/local/pf/lib);
use Sereal::Encoder qw(sereal_encode_with_object);
use Redis;
use pf::config;
use pf::log;
use NetSNMP::TrapReceiver;
our $encoder = Sereal::Encoder->new;

sub receiver {
    my ($trapInfo,$oids) = @_;
    local $ENV{REDIS_SERVER} = $Config{vlan}{trap_redis_pickup_server};
    my $redis = Redis->new ( encoding => undef);
    #Serializing the OID to a string
    foreach my $oid (@$oids) {
        $oid->[0] = $oid->[0]->quote_oid;
    }
    eval {
        $redis->lpush($Config{vlan}{trap_dropoff_queue}, sereal_encode_with_object($encoder,[$trapInfo,$oids]));
    };
    warn $@ if $@;
    return NETSNMPTRAPD_HANDLER_OK;
}

NetSNMP::TrapReceiver::register("all", \&receiver) || 
    warn "failed to register perl trap handler\n";
 
=head1 AUTHOR

Inverse inc. <info@inverse.ca>

=head1 COPYRIGHT

Copyright (C) 2005-2014 Inverse inc.

=head1 LICENSE

This program is free software; you can redistribute it and::or
modify it under the terms of the GNU General Public License
as published by the Free Software Foundation; either version 2
of the License, or (at your option) any later version.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
GNU General Public License for more details.

You should have received a copy of the GNU General Public License
along with this program; if not, write to the Free Software
Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301,
USA.

=cut

1;

