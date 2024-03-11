package pfappserver::Form::Field::RadiusAnswer;

=head1 NAME

pfappserver::Form::Field::RadiusAnswer -

=head1 DESCRIPTION

pfappserver::Form::Field::RadiusAnswer

=cut

use strict;
use warnings;
use HTML::FormHandler::Moose;
extends 'HTML::FormHandler::Field::Compound';

has '+inflate_default_method'=> ( default => sub { \&inflate } );
has '+deflate_value_method'=> ( default => sub { \&deflate } );
#reply", "proxy-request", "proxy-reply", "coa", "disconnect", "session-state", or "control
has_field 'prefix' => (
    type => 'Select',
    options => [
        {
            label => 'Request',
            value => 'request'
        },
        {
            label => 'Control',
            value => 'control'
        },
        {
            label => 'Config',
            value => 'config'
        },
        {
            label => 'Reply',
            value => 'reply'
        },
        {
            label => 'Proxy Request',
            value => 'proxy-request'
        },
        {
            label => 'Proxy Reply',
            value => 'proxy-reply'
        },
        {
            label => 'CoA',
            value => 'coa'
        },
        {
            label => 'Disconnect',
            value => 'disconnect'
        },
        {
            label => 'Session State',
            value => 'session-state'
        },
    ],
);

has_field 'type' => (
    type           => 'Text',
    widget_wrapper => 'None',
    do_label       => 0,
    required       => 1,
    tags           => {
        allowed_lookup => sub {
            {
                search_path => "/api/v1/radius_attributes",
                field_name  => "name",
                value_name  => 'name',
            };
        },
        allow_custom   => 1,
        option_pattern => sub {
            {
                message => "A RADIUS attribute name",
                regex => "^[0-9A-Za-z-\.:_-]+\$",
            };
          }
    },
);

has_field 'value' => (
    type           => 'Text',
    do_label       => 0,
    required       => 1,
    widget_wrapper => 'None',
);

=head2 inflate

inflate the value from the config store

=cut

sub inflate {
    my ($self, $data) = @_;
    my $prefix = '';
    my ($name, $value) = split /\s*=\s*/, $data, 2;
    my $type = $name;;
    if ($name =~ /:/) {
        ($prefix, $type) = split /:/, $name;
    }
    return {prefix => $prefix, type => $type, value => $value }
}

=head2 deflate

deflate to be saved into the config store

=cut

sub deflate {
    my ($self, $data) = @_;
    my $name = $data->{type};
    my $value = $data->{value};
    my $prefix = $data->{prefix};
    if ($prefix ne '') {
        $name = "${prefix}:$name";
    }

    return join(" = ", $name, $value);
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

