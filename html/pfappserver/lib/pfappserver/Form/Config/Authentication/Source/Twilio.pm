package pfappserver::Form::Config::Authentication::Source::Twilio;

=head1 NAME

pfappserver::Form::Config::Authentication::Source::Twilio

=cut

=head1 DESCRIPTION

Form definition to create or update a Twilio authentication source.

=cut

use strict;
use warnings;

use HTML::FormHandler::Moose;

extends 'pfappserver::Form::Config::Authentication::Source';
with 'pfappserver::Base::Form::Role::Help';

has_field 'account_sid' => (
    type        => 'Text',
    label       => 'Account SID',
    required    => 1,
    tags        => {
        after_element   => \&help,
        help            => 'Twilio Account SID',
    },
);

has_field 'auth_token' => (
    type        => 'Text',
    label       => 'Auth Token',
    required    => 1,
    tags        => {
        after_element   => \&help,
        help            => 'Twilio Auth Token',
    },
);

has_field 'twilio_phone_number' => (
    type            => 'Text',
    label           => 'Phone Number (From)',
    required        => 1,
    tags            => {
        after_element   => \&help,
        help            => 'Twilio provided phone number which will be used as a From',
    },
    element_attr    => {
        placeholder     => pf::Authentication::Source::TwilioSource->meta->get_attribute('twilio_phone_number')->default,
    },
    default         => pf::Authentication::Source::TwilioSource->meta->get_attribute('twilio_phone_number')->default,
);


=head1 AUTHOR

Inverse inc. <info@inverse.ca>

=head1 COPYRIGHT

Copyright (C) 2005-2017 Inverse inc.

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

