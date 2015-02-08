package pf::Switch::HP::MSM;

=head1 NAME

pf::Switch::HP::MSM

=head1 SYNOPSIS

The pf::Switch::HP::MSM module manages access to HP Procurve access point MSM

=head1 STATUS

Should work on all HP Wireless Access Point

=cut

use strict;
use warnings;

use Log::Log4perl;
use POSIX;

use base ('pf::Switch::HP::Controller_MSM710');

use pf::config;
sub description { 'HP ProCurve MSM Access Point' }

# importing switch constants
use pf::Switch::constants;
use pf::util;
use Net::Appliance::Session;

=head1 SUBROUTINES

=over

=cut

=item _deauthenticateMacWithSSH

Method to deauthenticate a node with SSH

=cut

sub _deauthenticateMacWithSSH {
    my ( $this, $mac ) = @_;
    my $logger = Log::Log4perl::get_logger( ref($this) );
    my $session;
    my @addition_ops;
    if (defined $this->{_controllerPort} && $this->{_cliTransport} eq 'SSH' ) {
        @addition_ops = (
            connect_options => {
                ops => [ '-p' => $this->{_controllerPort}  ]
            }
        );
    }
    eval {
        $session = Net::Appliance::Session->new(
            Host      => $this->{_ip},
            Timeout   => 20,
            Transport => $this->{_cliTransport},
            Platform => 'HP',
            Source   => $lib_dir.'/pf/Switch/HP/nas-pb.yml',
            @addition_ops
        );
        $session->connect(
            Name     => $this->{_cliUser},
            Password => $this->{_cliPwd}
        );
    };

    if ($@) {
        $logger->error( "ERROR: Can not connect to controller $this->{'_ip'} using "
                . $this->{_cliTransport} );
        return 1;
    }
    $session->cmd("enable");
    $session->cmd("disassociate wireless client $mac");
    $session->close();

    return 1;
}

=item deauthTechniques

Return the reference to the deauth technique or the default deauth technique.

=cut

sub deauthTechniques {
    my ($this, $method) = @_;
    my $logger = Log::Log4perl::get_logger( ref($this) );
    my $default = $SNMP::SSH;
    my %tech = (
        $SNMP::SSH  => '_deauthenticateMacWithSSH',
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

Copyright (C) 2005-2015 Inverse inc.

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
