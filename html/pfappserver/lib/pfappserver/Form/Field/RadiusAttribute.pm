package pfappserver::Form::Field::RadiusAttribute;

=head1 NAME

pfappserver::Form::Field::RadiusAttribute -

=head1 DESCRIPTION

pfappserver::Form::Field::RadiusAttribute

=cut

use strict;
use warnings;
use HTML::FormHandler::Moose;
extends 'HTML::FormHandler::Field::Compound';

has '+inflate_default_method'=> ( default => sub { \&inflate } );
has '+deflate_value_method'=> ( default => sub { \&deflate } );

has_field 'type' => (
    type           => 'Text',
    widget_wrapper => 'None',
    do_label       => 0,
    required       => 1,
    tags => {
        allowed_lookup => sub {
            {
                search_path => "/api/v1/radius_attributes",
                field_name  => "name",
                value_name  => 'name',
            }
        },
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
    my ($self, $value) = @_;
    my %data;
    @data{qw(type value)} = split /\s*=\s*/, $value, 2;
    return \%data;
}

=head2 deflate

deflate to be saved into the config store

=cut

sub deflate {
    my ($self, $value) = @_;
    return join(" = ", @{$value}{qw(type value)});
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

