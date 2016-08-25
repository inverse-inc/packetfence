package pfappserver::Model::Node::Tab::MSE;

=head1 NAME

pfappserver::Model::Node::Tab::MSE -

=cut

=head1 DESCRIPTION

pfappserver::Model::Node::Tab::MSE

=cut

use strict;
use warnings;
use Net::Cisco::MSE::REST;
use pf::config qw(%Config);
use pf::error qw(is_error is_success);
use base qw(pfappserver::Base::Model::Node::Tab);

=head2 process_tab

Process Tab

=cut

our $test_data = {
    'WirelessClientLocation' => {
        'Statistics' => {
            'currentServerTime' => '2016-08-23T13:53:03.915-0400',
            'lastLocatedTime'   => '2016-08-23T13:52:16.061-0400',
            'firstLocatedTime'  => '2016-08-23T13:52:16.040-0400'
        },
        'macAddress'    => 'ec:9b:f3:3d:de:31',
        'band'          => 'UNKNOWN',
        'ssId'          => 'CUSM-MUHC-PUBLIC',
        'ipAddress'     => ['10.36.34.49'],
        'apMacAddress'  => '7c:95:f3:01:d3:a0',
        'MapCoordinate' => {
            'y'    => '220.04',
            'unit' => 'FEET',
            'x'    => '168.32'
        },
        'isGuestUser' => 0,
        'MapInfo'     => {
            'Dimension' => {
                'width'   => '296.5',
                'unit'    => 'FEET',
                'length'  => '327.4',
                'offsetY' => '0',
                'offsetX' => '0',
                'height'  => '10'
            },
            'mapHierarchyString' => 'CampusGlen>BlocB>S2',
            'Image'              => {
                'imageName' => 'domain_0_1404755339511.jpg'
            },
            'floorRefId' => '-6045787246513093576'
        },
        'confidenceFactor' => '256',
        'dot11Status'      => 'ASSOCIATED',
        'currentlyTracked' => 1,
    }
};

sub process_tab {
    my ($self, $c, @args) = @_;
    return ($STATUS::OK, {localisation => $test_data});
    my $rest = Net::Cisco::MSE::REST->new(%{$Config{mse}});
    my $localisation;
    eval {
        $localisation = $rest->real_time_localisation_for_client({id => $c->stash->{mac}});
    };
    if ($@) {
    }
    return ($STATUS::OK, {localisation => $localisation});
}

=head1 AUTHOR

Inverse inc. <info@inverse.ca>

=head1 COPYRIGHT

Copyright (C) 2005-2016 Inverse inc.

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
