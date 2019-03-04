package pf::Switch::Dell::PowerConnect3424;

=head1 NAME

pf::Switch::Dell::PowerConnect3424 - Object oriented module to access SNMP enabled Dell PowerConnect3424 switches

=head1 SYNOPSIS

The pf::Switch::Dell::PowerConnect3424 module implements an object oriented interface to access SNMP enabled Dell:PowerConnect3424 switches.

The minimum required firmware version is 112.

=head1 CONFIGURATION AND ENVIRONMENT

F<conf/switches.conf>

=cut

use strict;
use warnings;
use Data::Dumper;

use base ('pf::Switch::Dell');

sub description { 'Dell PowerConnect 3424' }

sub getMinOSVersion {
    my ($self) = @_;
    my $logger = $self->logger;
    return '112';
}

sub _setVlan {
    my ( $self, $ifIndex, $newVlan, $oldVlan, $switch_locker_ref ) = @_;
    my $logger = $self->logger;
    my $session;

    eval {
        require Net::Telnet;
        $session = new Net::Telnet( Host => $self->{_ip}, Timeout => 20 );

        #$session->dump_log();
        $session->waitfor('/Password:/');
        $session->print( $self->{_cliPwd} );
        $session->waitfor('/>/');
    };
    if ($@) {
        $logger->error(
            "ERROR: Can not connect to switch $self->{'_ip'} using Telnet");
        return 1;
    }

    $session->print('enable');
    $session->waitfor('/Password:/');
    $session->print( $self->{_cliEnablePwd} );
    $session->waitfor('/#/');
    $session->print('configure');
    $session->waitfor('/\(config\)#/');
    $session->print( 'interface ethernet e' . $ifIndex );
    $session->waitfor('/\(config-if\)#/');
    $session->print( 'switchport access vlan ' . $newVlan );
    $session->waitfor('/\(config-if\)#/');
    $session->print("end");
    $session->waitfor('/#/');

    $session->close();
    return 1;

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
