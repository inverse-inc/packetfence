package pf::UnifiedApi::Controller::Config::FilterEngines;

=head1 NAME

pf::UnifiedApi::Controller::Config::FilterEngines -

=head1 DESCRIPTION

pf::UnifiedApi::Controller::Config::FilterEngines

=cut

use strict;
use warnings;
use Mojo::Base qw(pf::UnifiedApi::Controller::RestRoute);
use pf::condition_parser qw(parse_condition_string ast_to_object);

sub parse_condition {
    my ($self) = @_;
    my ($error, $item) = $self->get_json;
    if (defined $error) {
        return $self->render_error(400, "Bad Request : $error");
    }

    my $condition = $item->{condition};
    if (!defined $condition) {
        return $self->render_error(422, "No condition found");
    }

    if (ref $condition) {
        return $self->render_error(422, "Condition must be a string");
    }

    my ($ast, $err) = parse_condition_string($condition);
    if ($err) {
        return $self->render_error(422, "Cannot parse condition", [$err]);
    }

    $self->render(json => { item => {condition_string => $condition, condition => ast_to_object($ast) } });
}

sub flatten_condition {
    my ($self) = @_;
    my ($error, $item) = $self->get_json;
    if (defined $error) {
        return $self->render_error(400, "Bad Request : $error");
    }

    my $condition = $item->{condition};
    if (!defined $condition) {
        return $self->render_error(422, "No condition found");
    }

    if (!ref $condition) {
        return $self->render_error(422, "Condition must be a object");
    }

    my $string = pf::condition_parser::object_to_str($condition);

    $self->render(json => { item => {condition_string => $string, condition => $condition } });
}

=head2 engines

engines

=cut

sub engines {
    my ($self) = @_;
    $self->render(
        json => {
            items => [
                {
                    collection => "vlan_filters",
                    resource   => "vlan_filter",
                    name       => "VLAN Filters"
                },
                {
                    collection => "dhcp_filters",
                    resource   => "dhcp_filter",
                    name       => "DHCP Filters"
                },
                {
                    collection => "dns_filters",
                    resource   => "dns_filter",
                    name       => "DNS Filters"
                },
                {
                    collection => "radius_filters",
                    resource   => "radius_filter",
                    name       => "RADIUS Filters"
                },
                {
                    collection => "switch_filters",
                    resource   => "switch_filter",
                    name       => "Switch Filters"
                },
            ]
        }
    );
}

=head1 AUTHOR

Inverse inc. <info@inverse.ca>

=head1 COPYRIGHT

Copyright (C) 2005-2020 Inverse inc.

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

