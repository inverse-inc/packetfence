package pf::factory::connector;

=head1 NAME

pf::factory::connector

=cut

=head1 DESCRIPTION

pf::factory::connector

=cut

use strict;
use warnings;
use pf::connector;
use pf::config qw(%ConfigConnector);

tie my @connectors_ordered, 'pfconfig::cached_array', 'resource::connectors_ordered';

sub factory_for { 'pf::connector' }

sub new {
    my ($class,$name) = @_;
    my $object;
    if (!exists $ConfigConnector{$name}) {
        return undef;
    }

    my $data = $ConfigConnector{$name};
    if (!defined $data) {
        return undef;
    }

    $data->{id} = $name;

    return pf::connector->new(%$data);
}

sub local_connector {
    my ($class) = @_;
    return $class->new("local_connector");
}

sub for_ip {
    my ($class, $ip) = @_;
    $ip = NetAddr::IP->new($ip);
    for my $connector_id (@connectors_ordered) {
        for my $net (@{$ConfigConnector{$connector_id}{networks}}) {
            $net = NetAddr::IP->new($net);
            if($net->contains($ip)) {
                return $class->new($connector_id);
            }
        }
    } 
    return $class->local_connector();
}

=head1 AUTHOR

Inverse inc. <info@inverse.ca>

=head1 COPYRIGHT

Copyright (C) 2005-2024 Inverse inc.

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

