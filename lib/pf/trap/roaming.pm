package pf::trap::roaming;

=head1 NAME

pf::trap::roaming add documentation

=cut

=head1 DESCRIPTION

pf::trap::roaming

=cut

use strict;
use warnings;
use Moo;
extends 'pf::trap';
use pf::Switch::constants;
use pf::config;


=head2 supportedOIDS

Returns the list of supported OIDS for this trap

=cut

sub supportedOIDS { qw(.1.3.6.1.4.1.26928.1.1.1.1.1.4) }

=head2 handle

handle the

=cut

sub handle {
    my ($self) = @_;
    my $switch = $self->switch;
    my $oids = $self->oids;
    my $trapHashRef = {};
    my %values;
    foreach my $oid (@$oids) {
        my ($tempo, $value) = split(/: /, $oid->[1]);
        $value =~ s/^\s+|\s+$//g if (defined($value));
        $values{$oid->[0]} = $value;
    }
    my $trapSSID = $values{$AEROHIVE::ahSSID};
    $trapSSID =~ s/"//g;
    my $trapIfIndex = $values{$AEROHIVE::ahIfIndex};
    my $trapVlan = $values{$AEROHIVE::ahClientVLAN};
    my $trapMac = $values{$AEROHIVE::ahRemoteId};
    my $trapClientUserName = $values{$AEROHIVE::ahClientUserName};
    my $trapConnectionType = $WIRELESS_MAC_AUTH;
    if ($values{$AEROHIVE::ahClientAuthMethod} eq '6' || $values{$AEROHIVE::ahClientAuthMethod} eq '7') {
        $trapConnectionType = $WIRELESS_802_1X;
    }
    locationlog_synchronize($switch->{_id}, $switch->{_ip}, $switch->{_switchMac}, $trapIfIndex, $trapVlan, $trapMac, $NO_VOIP, $trapConnectionType, $trapClientUserName, $trapSSID );
}


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

