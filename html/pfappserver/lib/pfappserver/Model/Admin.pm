package pfappserver::Model::Admin;

=head1 NAME

pfappserver::Model::Admin - Catalyst Model

=head1 DESCRIPTION

Catalyst Model.

=cut

use strict;
use warnings;

use Moose;
use namespace::autoclean;

use pf::file_paths qw($conf_dir);
use pf::log;

=head1 METHODS


=head2 pf_release

Returns the content of conf/pf-release

=cut

sub pf_release {
    my ($self) = @_;

    return pf::version::version_get_release();
}

=head2 fingerbank_version

Returns the version of Fingerbank from conf/dhcp_fingerprins.conf

=cut

sub fingerbank_version {
    my $logger = get_logger();
    my ($filehandler, $line, $version);
    open( $filehandler, '<', "$conf_dir/dhcp_fingerprints.conf" )
        || $logger->error("Unable to open $conf_dir/dhcp_fingerprints.conf: $!");
    $line = <$filehandler>; # read the first line
    close $filehandler;
    ($version) = $line =~ m/version ([0-9\.]+)/i;
    return $version;
}

=head2 server_hostname

Returns the server hostname on which PacketFence is actually running

=cut

sub server_hostname {
    my ( $self ) = @_;
    return pf::cluster::get_host_id();
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
