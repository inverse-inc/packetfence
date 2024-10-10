package pfappserver::Form::Field::SwitchParam;

=head1 NAME

pfappserver::Form::Field::SwitchParam -

=cut

=head1 DESCRIPTION

pfappserver::Form::Field::SwitchParam

=cut

use strict;
use warnings;

use HTML::FormHandler::Moose;
extends 'HTML::FormHandler::Field::Compound';
use namespace::autoclean;
use pf::log;
use pf::constants::filters qw(@SWITCH_FIELDS);

has '+inflate_default_method'=> ( default => sub { \&inflate } );
has '+deflate_value_method'=> ( default => sub { \&deflate } );
has '+widget_wrapper' => (default => 'Bootstrap');
has '+do_label' => (default => 1 );

has_field type => (
    type => 'Select',
    do_label => 0,
    options_method => \&options_type,
    required => 1,
    widget_wrapper => 'None',
    element_class => ['input-medium'],
);

has_field value => (
    type => 'Text',
    do_label => 0,
    required => 1,
    widget_wrapper => 'None',
    element_class => ['input-xxlarge'],
);

sub parse_type_value {
    my ($value) = @_;
    my %hash;
    @hash{qw(type value)} = split(/\s*=\s*/, $value, 2);
    return \%hash;
}

=head2 inflate

inflate the api method spec string to a hash

=cut

sub inflate {
    my ($self, $value) = @_;
    if (ref $value) {
        return $value;
    }

    my $hash = parse_type_value($value) // {};
    return $hash;
}

=head2 deflate

deflate the api method spec hash to a string

=cut

sub deflate {
    my ($self, $value) = @_;
    return join("=", $value->{type}, $value->{value});
}

sub options_type {
    return map { my $f = $_;$f =~ s/^switch\._//; { value => $f, label => $f } } @SWITCH_FIELDS;
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
