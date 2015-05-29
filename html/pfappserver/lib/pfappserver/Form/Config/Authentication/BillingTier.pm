package pfappserver::Form::Config::Authentication::BillingTier;

=head1 NAME

pfappserver::Form::Config::Authentication::BillingTier - Rules of a user source

=head1 DESCRIPTION

Form definition to manage the rules (conditions and actions) of an
authentication source.

=cut

use HTML::FormHandler::Moose;
extends 'pfappserver::Base::Form';
use pf::Authentication::constants;

# Form select options

# Form fields
has_field 'id' => (
    type     => 'Text',
    label    => 'Name',
    required => 1,
    messages => {required => 'Please specify an identifier for the rule.'},
    apply    => [{check => qr/^\S+$/, message => 'The name must not contain spaces.'}],
);

has_field 'description' => (
    type     => 'Text',
    label    => 'Description',
    required => 0,
);

=head2 name

=cut

has_field 'name' => (type => 'Text',);

=head2 price

=cut

has_field 'price' => (type => 'Text',);

=head2 timeout

=cut

has_field 'timeout' => (type => 'Text');

=head2 category

=cut

has_field 'category' => (type => 'Text',);

=head2 description

=cut

has_field 'description' => (type => 'Text',);

=head2 destination_url

=cut

has_field 'destination_url' => (type => 'Text',);

=head1 COPYRIGHT

Copyright (C) 2005-2015 Inverse inc.

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

__PACKAGE__->meta->make_immutable;
1;
