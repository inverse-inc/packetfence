package pf::Switch::Dell::Force10;

=head1 NAME

pf::Switch::Dell::Force10 - Object oriented module to access SNMP enabled Dell Force10 switches

=head1 SYNOPSIS

The pf::Switch::Dell::Force10 module implements an object oriented interface to access SNMP enabled Dell:Force10 switches.

The minimum required firmware version is ...

=head1 CONFIGURATION AND ENVIRONMENT

F<conf/switches.conf>

=cut

use strict;
use warnings;
use pf::constants;
use base ('pf::Switch::Dell');

sub description { 'Dell Force 10' }

# CAPABILITIES
# access technology supported
sub supportsWiredMacAuth { return $TRUE; }
sub supportsWiredDot1x { return $TRUE; }
# VoIP technology supported
sub supportsRadiusVoip { return $TRUE; }
# override 2950's FALSE
sub supportsRadiusDynamicVlanAssignment { return $TRUE; }

sub getMinOSVersion {
    my ($self) = @_;
    my $logger = $self->logger;
    return '112';
}

=head2 getIfIndexByNasPortId

Fetch the ifindex on the switch by NAS-Port-Id radius attribute

=cut

sub getIfIndexByNasPortId {
    my ($self, $ifDesc_param) = @_;
    my $logger = $self->logger;

    if ( !$self->connectRead() || !defined($ifDesc_param)) {
        return 0;
    }

    my @ifDesc_val = split('/',$ifDesc_param);
    my $OID_ifDesc = '1.3.6.1.2.1.17.1.4.1.2.'.$ifDesc_param;
    my $result = $self->cachedSNMPRequest([-varbindlist => [ $OID_ifDesc ]]);
    return $result->{"$OID_ifDesc"};
}


=head1 AUTHOR

Inverse inc. <info@inverse.ca>

=head1 COPYRIGHT

Copyright (C) 2005-2019 Inverse inc.

=head1 LICENSE

This program is free software; you can redistribute it and/or
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

# vim: set shiftwidth=4:
# vim: set expandtab:
# vim: set backspace=indent,eol,start:
