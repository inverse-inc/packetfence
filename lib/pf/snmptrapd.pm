package pf::snmptrapd;

=head1 NAME

pfsnmptrapd

=cut

=head1 DESCRIPTION

pfsnmptrapd

=cut

use strict;
use warnings;
use lib qw(/usr/local/pf/lib);
use NetSNMP::TrapReceiver;
use pf::pfqueue::producer::redis;
#      "receivedfrom" : "UDP: [192.168.57.101]:36745->[192.168.57.101]",
our $TRAP_RECEIVED_FROM = qr/
    (?:UDP:\ \[)?
    (\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3})
    (?:\]\d+)?

/sx;

=head2 receiver

=cut

sub receiver {
    my ($trapInfo, $variables) = @_;
    #Serializing the OID to a string
    fixUpOids($variables);
    my $switchIp;
    if($trapInfo->{receivedfrom} =~ $TRAP_RECEIVED_FROM) {
        $trapInfo->{switchIp} = $switchIp = $1;
    }
    return NETSNMPTRAPD_HANDLER_FAIL unless defined $switchIp;
    my $producer = pf::pfqueue::producer::redis->new({
        redis => _redis_client(),
    });
#    Delay parsing by two seconds to allow snmp to do it's magic
    $producer->submit_delayed("pfsnmp_parsing", "pfsnmp_parsing", 2000, [$trapInfo, $variables]);
    return NETSNMPTRAPD_HANDLER_OK;
}

sub fixUpOids {
    my ($variables) = @_;
    foreach my $variable (@$variables) {
        $variable->[0] = $variable->[0]->quote_oid;
    }
}

NetSNMP::TrapReceiver::register("all", \&receiver) || warn "failed to register perl trap handler\n";

sub _redis_client {
    return pf::Redis->new(
        server    => '127.0.0.1:6380',
        reconnect => 1,
        every     => 100,
    );
}

 
=head1 AUTHOR

Inverse inc. <info@inverse.ca>

=head1 COPYRIGHT

Copyright (C) 2005-2018 Inverse inc.

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
