package pfappserver::Form::Field::PfdetectRegexRule;

=head1 NAME

pfappserver::Form::Field::PfdetectRegexRule - The detect::parser::regex rule

=cut

=head1 DESCRIPTION

=cut

use pfappserver::Form::Field::DynamicList;
use HTML::FormHandler::Moose;
extends 'HTML::FormHandler::Field::Compound';
use namespace::autoclean;

=head2 name

Name

=cut

has_field 'name' => (
    type     => 'Text',
    label    => 'Name',
    required => 1,
    messages => {required => 'Please specify the name of the rule'},
);

=head2 regex

Regex

=cut

has_field 'regex' => (
    type     => 'Regex',
    label    => 'Regex',
    element_class => ['input-xxlarge'],
    required => 1,
    messages => {required => 'Please specify the regex pattern using named captures'},
);

=head2 actions

The list of action

=cut

has_field 'actions' => (
    'type' => 'DynamicList',
);

=head2 actions.contains

The definition for the list of actions

=cut

has_field 'actions.contains' => (
    type  => 'ApiAction',
    label => 'Action',
    pfappserver::Form::Field::DynamicList::child_options(),
);

=head2 last_if_match

last if match

=cut

has_field 'last_if_match' => (
    type            => 'Toggle',
    label           => 'Last If match',
    messages        => {required => 'Please specify the if the add_event is sent'},
    checkbox_value  => 'enabled',
    unchecked_value => 'disabled',
);

=head2 ip_mac_translation

If enabled then do ip to mac and mac to ip translation

=cut

has_field 'ip_mac_translation' => (
    type            => 'Toggle',
    label           => 'Do IP to MAC and MAC to IP translation',
    default         => 'enabled',
    checkbox_value  => 'enabled',
    unchecked_value => 'disabled',
);

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
