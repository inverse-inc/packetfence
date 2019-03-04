package pf::Switch::Trapeze;

=head1 NAME

pf::Switch::Trapeze

=head1 SYNOPSIS

Module to manage Trapeze controllers

=cut

use strict;
use warnings;

use POSIX;

use base ('pf::Switch');

use pf::constants;
use pf::file_paths qw($lib_dir);
use pf::config qw(
    $MAC
    $SSID
);
sub description { 'Trapeze Wireless Controller' }

# importing switch constants
use pf::Switch::constants;
use pf::util;

=head1 STATUS

=head1 BUGS AND LIMITATIONS

=over

=item CLI deauthentication

De-authentication of a Wireless user is based on CLI access (Telnet or SSH).
This is a vendor issue and it might be fixed in newer firmware versions.

=back

=head1 SUBROUTINES

=over

=cut

# CAPABILITIES
# access technology supported
sub supportsWirelessDot1x { return $TRUE; }
sub supportsWirelessMacAuth { return $TRUE; }
# inline capabilities
sub inlineCapabilities { return ($MAC,$SSID); }

=item getVersion

obtain image version information from switch

=cut

sub getVersion {
    my ($self) = @_;
    my $oid_ntwsVersionString = '1.3.6.1.4.1.45.6.1.4.2.1.4';
    my $logger = $self->logger;
    if ( !$self->connectRead() ) {
        return '';
    }

    # mwWncVarsSoftwareVersion sample output:
    # 7.0.14.1.0

    # first trying with a .0
    $logger->trace("SNMP get_request for ntwsVersionString: $oid_ntwsVersionString.0");
    my $result = $self->{_sessionRead}->get_request( -varbindlist => [$oid_ntwsVersionString.".0"] );
    if (defined($result)) {
        return $result->{$oid_ntwsVersionString.".0"};
    }

    # then trying straight
    $logger->trace("SNMP get_request for ntwsVersionString: $oid_ntwsVersionString");
    $result = $self->{_sessionRead}->get_request( -varbindlist => [$oid_ntwsVersionString] );
    if (defined($result)) {
        return $result->{$oid_ntwsVersionString};
    }

    # none of the above worked
    $logger->warn("unable to fetch version information");
}

=item deauthenticateMacDefault

deauthenticate a MAC address from wireless network

Right now te only way to do it is from the CLi (through Telnet or SSH).

=cut

sub deauthenticateMacDefault {
    my ( $self, $mac ) = @_;
    my $logger = $self->logger;

    if ( !$self->isProductionMode() ) {
        $logger->info("not in production mode ... we won't deauthenticate $mac");
        return 1;
    }

    if ( length($mac) != 17 ) {
        $logger->error("MAC format is incorrect ($mac). Should be xx:xx:xx:xx:xx:xx");
        return 1;
    }

    my $session;
    eval {
        require Net::Appliance::Session;
        $session = Net::Appliance::Session->new(
            Host      => $self->{_ip},
            Timeout   => 5,
            Transport => $self->{_cliTransport},
            Platform => 'TrapezeOS',
            Source   => $lib_dir.'/pf/Switch/Trapeze/nas-pb.yml'
        );
        $session->connect(
            Name     => $self->{_cliUser},
            Password => $self->{_cliPwd}
        );
    };

    if ($@) {
        $logger->error("Unable to connect to ".$self->{'_ip'}." using ".$self->{_cliTransport}.". Failed with $@");
        return;
    }

    if (!$session->in_privileged_mode()) {
        if (!$session->enable($self->{_cliEnablePwd})) {
            $logger->error("Cannot get into privileged mode on ".$self->{'_id'}.
                           ". Are you sure you provided enable password in configuration?");
            $session->close();
            return;
        }
    }

    my $command = "clear sessions network mac-addr $mac";

    $logger->info("Deauthenticating mac $mac");
    $logger->trace("sending CLI command '$command'");
    my @output;
    $session->in_privileged_mode(1);
    eval {
        @output = $session->cmd(String => $command, Timeout => '10');
    };
    $session->in_privileged_mode(0);
    if ($@) {
        $logger->error("Unable to deauthenticate $mac: $@");
        $session->close();
        return;
    }
    $session->close();
    return 1;
}

=item deauthTechniques

Return the reference to the deauth technique or the default deauth technique.

=cut

sub deauthTechniques {
    my ($self, $method) = @_;
    my $logger = $self->logger;
    my $default = $SNMP::TELNET;
    my %tech = (
        $SNMP::TELNET => 'deauthenticateMacDefault',
        $SNMP::SSH  => 'deauthenticateMacDefault',
    );

    if (!defined($method) || !defined($tech{$method})) {
        $method = $default;
    }
    return $method,$tech{$method};
}

=back

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
