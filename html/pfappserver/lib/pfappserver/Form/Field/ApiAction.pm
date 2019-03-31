package pfappserver::Form::Field::ApiAction;

=head1 NAME

pfappserver::Form::Field::ApiAction -

=cut

=head1 DESCRIPTION

pfappserver::Form::Field::ApiAction

=cut

use strict;
use warnings;

use HTML::FormHandler::Moose;
extends 'HTML::FormHandler::Field::Compound';
use namespace::autoclean;
use pf::api;

use pf::config;
use pf::factory::condition::profile;
use pf::validation::profile_filters;
use pf::log;
use pf::util qw(parse_api_action_spec);

has '+inflate_default_method'=> ( default => sub { \&inflate } );
has '+deflate_value_method'=> ( default => sub { \&deflate } );
has '+widget_wrapper' => (default => 'Bootstrap');
has '+do_label' => (default => 1 );

has_field api_method => (
    type => 'Select',
    do_label => 0,
    required => 1,
    widget_wrapper => 'None',
    options_method => \&options_api_method,
    element_class => ['input-medium'],
    localize_labels => 1,
);

has_field api_parameters => (
    type => 'Text',
    do_label => 0,
    required => 1,
    default => ' ',
    widget_wrapper => 'None',
    element_class => ['input-xxlarge'],
);


=head2 inflate

inflate the api method spec string to a hash

=cut

sub inflate {
    my ($self, $value) = @_;
    my $hash = parse_api_action_spec($value) // {};
    return $hash;
}

=head2 deflate

deflate the api method spec hash to a string

=cut

sub deflate {
    my ($self, $value) = @_;
    return "$value->{api_method}: $value->{api_parameters}";
}

=head2 options_api_method

Provide a list of api methods

=cut

sub options_api_method {
    my ($self) = @_;
    return {value => '', label => '--- choose ---'}, map {/^pf::api::(.*)$/;{value => $1, label => $1}} sort keys %pf::api::attributes::ALLOWED_ACTIONS;

}

pf::api::attributes::updateAllowedAsActions();
 
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

