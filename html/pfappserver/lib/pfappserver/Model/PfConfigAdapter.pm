package pfappserver::Model::PfConfigAdapter;
use Moose;
use namespace::autoclean;

extends 'Catalyst::Model';

use Try::Tiny;

use pf::log;
use pf::constants;
use pf::config qw(
    $management_network
    %Config
);
use pfconfig::manager;

=head1 NAME

pfappserver::Model::PfConfigAdapter - Catalyst Model

=head1 DESCRIPTION

A wrapper above pf::config to expose some of its feature. The longer term
plan is to migrate out of pf::config and all into Web Services.


=head2 getWebAdminIp

Returns the IP where the Web Administration interface runs.

Will prefer returning the virtual IP if there's one.

=cut

sub getWebAdminIp {
    my ($self) = @_;
    my $logger = get_logger();

    my $mgmt_net = $management_network;
    my $ip = undef;
    if ($mgmt_net) {
        $ip = (defined($mgmt_net->tag('vip'))) ? $mgmt_net->tag('vip') : $mgmt_net->tag('ip');
    }

    return $ip;
}

=head2 getWebAdminPort

Returns the port on which the Web Administration interface runs.

=cut

sub getWebAdminPort {
    my ($self) = @_;
    my $logger = get_logger();

    return $Config{'ports'}{'admin'};
}

=head2 reloadConfiguration

Tell pf::config to reload its configuration.

=cut

sub reloadConfiguration {
    my ($self) = @_;
    my $logger = get_logger();

    $logger->info("reloading PacketFence configuration");

    my $status = pfconfig::manager->new->expire_all;
    pf::config::configreload(1);

    $logger->info("done reloading PacketFence configuration");
    return $TRUE;

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

__PACKAGE__->meta->make_immutable unless $ENV{"PF_SKIP_MAKE_IMMUTABLE"};

1;
