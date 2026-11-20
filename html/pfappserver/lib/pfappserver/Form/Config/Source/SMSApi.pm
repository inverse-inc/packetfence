package pfappserver::Form::Config::Source::SMSApi;

=head1 NAME

pfappserver::Form::Config::Source::SMSApi

=cut

=head1 DESCRIPTION

Form definition to create or update an SMSApi authentication source.

=cut

use strict;
use warnings;

use HTML::FormHandler::Moose;

extends 'pfappserver::Form::Config::Source';
with 'pfappserver::Base::Form::Role::Help';
with 'pfappserver::Base::Form::Role::SourceLocalAccount';

use pf::Authentication::Source::SMSApiSource;

our $META = pf::Authentication::Source::SMSApiSource->meta;

has_field 'api_protocol' => (
    type    => 'Select',
    label   => 'API Protocol',
    options => [ { label => 'https', value => 'https' }, { label => 'http', value => 'http' } ],
    default => $META->get_attribute('api_protocol')->default,
    tags    => {
        after_element   => \&help,
        help            => 'Protocol used to reach the SMS gateway',
    },
);

has_field 'api_url' => (
    type            => 'Text',
    label           => 'API URL',
    required        => 1,
    # Default value needed for creating dummy source
    default         => '',
    element_attr    => {
        placeholder => 'platform.clickatell.com/messages/http/send',
    },
    validate_method => sub {
        my ($field) = @_;
        unless (pf::Authentication::Source::SMSApiSource::build_api_url('https', $field->value)) {
            $field->add_error('The API URL must be a host and path without the protocol');
        }
    },
    tags        => {
        after_element   => \&help,
        help            => 'URL of the Clickatell compatible SMS gateway, without the protocol',
    },
);

has_field 'api_key' => (
    type        => 'Text',
    label       => 'API Key',
    required    => 1,
    # Default value needed for creating dummy source
    default     => '',
    tags        => {
        after_element   => \&help,
        help            => 'SMS gateway API Key',
    },
);

has_field 'timeout' => (
    type         => 'PosInteger',
    label        => 'Timeout',
    element_attr => {
        placeholder => $META->get_attribute('timeout')->default,
    },
    default      => $META->get_attribute('timeout')->default,
    tags         => {
        after_element   => \&help,
        help            => 'Timeout in seconds of the HTTP request to the SMS gateway',
    },
);

has_field 'message' => (
    type => 'TextArea',
    label => 'SMS text message ($pin will be replaced by the PIN number)',
    default => $META->get_attribute('message')->default,
);

has_field 'pin_code_length' => (
    type => 'PosInteger',
    label => 'PIN Code Length',
    default => $META->get_attribute('pin_code_length')->default,
    tags => {
        after_element => \&help,
        help => 'The length of the PIN code to be sent over sms',
    },
);


=head1 AUTHOR

Inverse inc. <info@inverse.ca>

=head1 COPYRIGHT

Copyright (C) 2005-2026 Inverse inc.

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
