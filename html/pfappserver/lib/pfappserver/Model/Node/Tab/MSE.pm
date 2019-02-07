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
use Clone qw(clone);
use Image::Magick;

our $_TEST_DATA = {
    'WirelessClientLocation' => {
        'Statistics' => {
            'currentServerTime' => '2016-08-23T13:53:03.915-0400',
            'lastLocatedTime'   => '2016-08-23T13:52:16.061-0400', # This
            'firstLocatedTime'  => '2016-08-23T13:52:16.040-0400' # This
        },
        'MapCoordinate' => {
            'y'    => '220.04',
            'unit' => 'FEET',
            'x'    => '168.32'
        },
        'MapInfo'     => {
            'Dimension' => {
                'width'   => '296.5',
                'unit'    => 'FEET',
                'length'  => '327.4',
                'offsetY' => '0',
                'offsetX' => '0',
                'height'  => '10'
            },
            'mapHierarchyString' => 'CampusGlen>BlocB>S2', # This
            'Image'              => {
                'imageName' => 'domain_0_1404755339511.jpg'
            },
            'floorRefId' => '-6045787246513093576'
        },
        'macAddress'    => 'ec:9b:f3:3d:de:31', # This
        'apMacAddress'  => '7c:95:f3:01:d3:a0', # This
        'band'          => 'UNKNOWN', # This
        'confidenceFactor' => '256',
        'currentlyTracked' => 1, # This
        'dot11Status'      => 'ASSOCIATED', # This
        'ipAddress'     => ['10.36.34.49'], # Ip address
        'isGuestUser' => 0, # This
        'ssId'          => 'CUSM-MUHC-PUBLIC', # This
    }
};

our @FIELDS = qw(
    macAddress apMacAddress band
    currentlyTracked dot11Status ipAddress
    isGuestUser ssId firstLocatedTime lastLocatedTime
    mapHierarchyString
);


=head2 process_tab

Process Tab

=cut

sub process_tab {
    my ($self, $c, $type, @args) = @_;
    my $rest = Net::Cisco::MSE::REST->new(%{$Config{mse_tab}});
    my $localisation;
    my $image;
    my $mac = $c->stash->{mac};
    eval {
        if ($type eq 'info') {
            $localisation = $rest->real_time_localisation_for_client({id => $mac});
        } elsif ($type eq 'history') {
            my $count = $rest->localisation_history_for_client_count({id => $mac});
            if ($count->{DeviceCount}->{count} > 0) {
                $localisation = $rest->localisation_history_for_client({id => $mac});
            }
        } elsif ($type eq 'image') {
            $localisation = $rest->real_time_localisation_for_client({id => $mac});
            $image = $rest->maps_image_source({imageName => $localisation->{WirelessClientLocation}->{MapInfo}->{Image}->{imageName}});
            my $bgimg = Image::Magick->new();
            $bgimg->BlobToImage($image);
            my $width  = $bgimg->Get('width');
            my $height = $bgimg->Get('height');
            my $x = $localisation->{WirelessClientLocation}->{MapCoordinate}->{'x'} * ($width / $localisation->{WirelessClientLocation}->{MapInfo}->{'Dimension'}->{'width'});
            my $y = $localisation->{WirelessClientLocation}->{MapCoordinate}->{'y'} * ($height / $localisation->{WirelessClientLocation}->{MapInfo}->{'Dimension'}->{'length'});
            my $radius = $localisation->{WirelessClientLocation}->{'confidenceFactor'} * ($height / $localisation->{WirelessClientLocation}->{MapInfo}->{'Dimension'}->{'length'});
            $image = $self->draw_circle($bgimg, $x, $y, $radius);
            $c->response->body($image);
            $c->response->content_type("image/jpeg");
        }
    };

    if ($@) {
        $c->log->error($@);
        return ($STATUS::INTERNAL_SERVER_ERROR, {status_msg => "Error retrieving information for $mac"});
    }
    my $wireless_client_loc =  $localisation->{WirelessClientLocation};
    $wireless_client_loc->{mapHierarchyString} = $wireless_client_loc->{MapInfo}{mapHierarchyString};
    my $stats = $wireless_client_loc->{Statistics};
    my @stats_keys = keys %$stats;
    @$wireless_client_loc{@stats_keys} = @{$stats}{@stats_keys};
    return ($STATUS::OK, {localisation => $localisation, fields => [@FIELDS]});
}

=head2 draw_circle

Draw a circle in the map

=cut

sub draw_circle {
    my ($self, $img, $center_x, $center_y, $radius) = @_;
    $img->Draw(
        interpolate => 'average',
        fill => 'transparent',
        stroke => 'red',
        points => "$center_x,$center_y @{[$center_x + $radius]},$center_y",
        primitive => 'circle',
    );
    $img->Draw(
        fill => 'red',
        stroke => 'red',
        points => "$center_x,$center_y @{[$center_x + 10]},$center_y",
        primitive => 'circle',
    );
    $img->Write;
    return $img->ImageToBlob();
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
