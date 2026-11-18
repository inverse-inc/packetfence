package pf::ipset;

=head1 NAME

pf::ipset - module for ipset tables management.

=cut

=head1 DESCRIPTION

pf::ipset contains the functions necessary to manipulate the
ipset tables (passthrough sets) used by the VLAN and DNS enforcement.

=cut

use strict;
use warnings;

BEGIN {
    use Exporter ();
    our ( @ISA, @EXPORT );
    @ISA = qw(Exporter);
    @EXPORT = qw(
        iptables_generate
    );
}

use pf::log;
use Readonly;

use pf::config qw(
    %Config
    $SELFREG_MODE_GITHUB
    $SELFREG_MODE_GOOGLE
    $SELFREG_MODE_FACEBOOK
);
use pf::util;
use pf::authentication;
use pf::constants;
use pf::config::cluster;

=head1 SUBROUTINES

=over

=item new

Constructor

=cut

sub new {
   my $logger = get_logger();
   $logger->debug("instantiating new pf::ipset object");
   my ( $class, %argv ) = @_;
   my $self = bless {}, $class;
   return $self;
}

=item iptables_generate

Destroy the existing ipsets and create the passthrough ipsets used by the VLAN and DNS enforcement

=cut

sub iptables_generate {
    my ($self) = @_;
    my $logger = get_logger();
    # init ipset tables
    $logger->warn("We are using IPSET");
    #Flush mangle table to permit ipset destroy
    $self->iptables_flush_mangle;
    my @lines = safe_pf_run(qw(sudo ipset --destroy));

    # OAuth and passthrough
    my $google_enabled = $guest_self_registration{$SELFREG_MODE_GOOGLE};
    my $facebook_enabled = $guest_self_registration{$SELFREG_MODE_FACEBOOK};
    my $github_enabled = $guest_self_registration{$SELFREG_MODE_GITHUB};
    my $passthrough_enabled = (isenabled($Config{'fencing'}{'passthrough'}) || isenabled($Config{'fencing'}{'isolation_passthrough'}));

    if ($google_enabled || $facebook_enabled || $github_enabled || $passthrough_enabled) {
        my @lines  = safe_pf_run(qw(sudo ipset --create pfsession_passthrough),  'hash:ip,port');
        @lines  = safe_pf_run(qw(sudo ipset --create pfsession_isol_passthrough), 'hash:ip,port');
    }
}

=item iptables_flush_mangle

Flush mangle table

=cut

sub iptables_flush_mangle {
    my ($self, $restore_file) = @_;
    my $logger = get_logger();
    $logger->info( "flushing iptables" );
    safe_pf_run(qw(/sbin/iptables -t mangle -F));
}

=back

=head1 AUTHOR

Inverse inc. <info@inverse.ca>

=head1 COPYRIGHT

Copyright (C) 2005-2026 Inverse inc.

=head1 LICENSE

This program is free software; you can redistribute it and/or
modify it under the terms of the GNU General Public License
as published by the Free Software Foundation; either version 2
of the License, or (at your option) any later version.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
GNU General Public License for more details.

You should have received a copy of the GNU General Public License
along with this program; if not, write to the Free Software
Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA 02110-1301,
USA.

=cut

1;
