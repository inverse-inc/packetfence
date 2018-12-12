package pfappserver::Form::Config::Source::Clickatell;

=head1 NAME

pfappserver::Form::Config::Source::Clickatell

=cut

=head1 DESCRIPTION

Form definition to create or update a Clickatell authentication source.

=cut

use strict;
use warnings;

use HTML::FormHandler::Moose;

extends 'pfappserver::Form::Config::Source';
with 'pfappserver::Base::Form::Role::Help';
with 'pfappserver::Base::Form::Role::SourceLocalAccount';

has_field 'api_key' => (
    type        => 'Text',
    label       => 'API Key',
    required    => 1,
    # Default value needed for creating dummy source
    default     => '',
    tags        => {
        after_element   => \&help,
        help            => 'Clickatell API Key',
    },
);

has_field 'message' => (
    type => 'TextArea',
    label => 'SMS text message ($pin will be replaced by the PIN number)',
    default => pf::Authentication::Source::SMSSource->meta->get_attribute('message')->default,
);

has_field 'pin_code_length' => (
    type => 'PosInteger',
    label => 'PIN Code Length',
    default => pf::Authentication::Source::ClickatellSource->meta->get_attribute('pin_code_length')->default,
    tags => {
        after_element => \&help,
        help => 'The length of the PIN code to be sent over sms',
    },
);


=head1 AUTHOR

Inverse inc. <info@inverse.ca>

=head1 COPYRIGHT

Copyright (C) 2005-2018 Inverse inc.

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

