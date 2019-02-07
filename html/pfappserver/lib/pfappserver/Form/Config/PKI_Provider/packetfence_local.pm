package pfappserver::Form::Config::PKI_Provider::packetfence_local;

=head1 NAME

pfappserver::Form::Config::PKI_Provider::packetfence_local

=cut

use strict;
use warnings;

use HTML::FormHandler::Moose;

extends 'pfappserver::Base::Form';
with 'pfappserver::Base::Form::Role::Help';

has_field 'id' => (
    type     => 'Text',
    label    => 'PKI Provider Name',
    required => 1,
    messages => { required => 'Please specify the name of the PKI provider' },
    tags     => { 
        after_element   => \&help,
        help            => 'The unique ID of the PKI provider',
    },
   apply => [ pfappserver::Base::Form::id_validator('PKI provider name') ]
);

has_field 'type' => (
    type        => 'Hidden',
    label       => 'PKI Provider type',
    required    => 1,
);

has_field 'client_cert_path' => (
    type        => 'Path',
    label       => 'Client cert path',
    required    => 1,
    tags        => { 
        after_element   => \&help,
        help            => 'Path of the client cert that will be used to generate the p12',
    },
);

has_field 'client_key_path' => (
    type        => 'Path',
    label       => 'Client key path',
    required    => 1,
    tags        => {
        after_element   => \&help,
        help            => 'Path of the client key that will be used to generate the p12',
    },
);

has_field 'ca_cert_path' => (
    type        => 'Path',
    label       => 'CA cert path',
    required    => 1,
    tags        => { 
        after_element   => \&help,
        help            => 'Path of the CA certificate used to generate client certificate/key combination',
    },
);

has_field 'server_cert_path' => (
    type        => 'Path',
    label       => 'Server cert path',
    required    => 1,
    tags        => { 
        after_element   => \&help,
        help            => 'Path of the RADIUS server authentication certificate',
    },
);

has_block 'definition' => (
    render_list => [ qw(type client_cert_path client_key_path ca_cert_path server_cert_path) ],
);

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

__PACKAGE__->meta->make_immutable unless $ENV{"PF_SKIP_MAKE_IMMUTABLE"};

1;
