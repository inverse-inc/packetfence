package pfappserver::Form::Portal::Common;

=head1 NAME

pfappserver::Form::Portal::Common add documentation

=cut

=head1 DESCRIPTION

pfappserver::Form::Portal::Common

=cut

use strict;
use warnings;
use HTML::FormHandler::Moose::Role;
use List::MoreUtils qw(uniq);
use pf::authentication;
with 'pfappserver::Base::Form::Role::Help';

=head1 Fields

=head2 id

Id of the profile

=cut

has_field 'id' =>
  (
   type => 'Text',
   label => 'Profile Name',
   required => 1,
   apply => [ { check => qr/^[a-zA-Z0-9][a-zA-Z0-9\._-]*$/ } ],
  );

=head2 description

Description of the profile

=cut

has_field 'description' =>
  (
   type => 'Text',
   label => 'Profile Description',
   required => 1,
  );

=head2 billing_engine

Has the billing engine enabled

=cut

has_field 'billing_engine' =>
  (
   type => 'Toggle',
   label => 'Enable Billing Engine',
   checkbox_value => 'enabled',
   unchecked_value => 'disabled',
   tags => { after_element => \&help,
             help => 'When enabling the billing engine, all authentication sources bellow are ignored.' },
  );

=head2 sources

Collectiosn Authentication Sources for the profile

=cut

has_field 'sources' =>
  (
    'type' => 'DynamicTable',
    'sortable' => 1,
    'do_label' => 0,
  );

=head2 sources.contains

The definition for Authentication Sources field

=cut

has_field 'sources.contains' =>
  (
    type => 'Select',
    options_method => \&options_sources,
    widget_wrapper => 'DynamicTableRow',
  );

=head1 Methods

=head2 options_sources

Returns the list of sources to be displayed

=cut

sub options_sources {
    return map { { value => $_->id, label => $_->id, attributes => { 'data-source-class' => $_->class  } } } @{getAllAuthenticationSources()};
}

=head2 validate

Remove duplicates and make sure only one external authentication source is selected for each type.

=cut

sub validate {
    my $self = shift;

    my @all = uniq @{$self->value->{'sources'}};
    $self->field('sources')->value(\@all);
    my %external;
    foreach my $source_id (@all) {
        my $source = &pf::authentication::getAuthenticationSource($source_id);
        next unless $source && $source->class eq 'external';
        $external{$source->{'type'}} = 0 unless (defined $external{$source->{'type'}});
        $external{$source->{'type'}}++;
        if ($external{$source->{'type'}} > 1) {
            $self->field('sources')->add_error('Only one authentication source of each external type can be selected.');
            last;
        }
    }
}


=head1 AUTHOR

Inverse inc. <info@inverse.ca>

=head1 COPYRIGHT

Copyright (C) 2005-2013 Inverse inc.

=head1 LICENSE

This program is free software; you can redistribute it and::or
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

