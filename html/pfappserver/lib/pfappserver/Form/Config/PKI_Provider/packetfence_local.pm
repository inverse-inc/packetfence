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
    required => 1,
    messages => { required => 'Please specify the name of the PKI provider' },
    tags     => { 
        after_element   => \&help,
        help            => 'The unique ID of the PKI provider',
    },
   apply => [ pfappserver::Base::Form::id_validator('PKI provider name') ],
   tags => {
      option_pattern => \&pfappserver::Base::Form::id_pattern,
   },
);

has_field 'type' => (
    type     => 'Hidden',
    required => 1,
    default  => 'packetfence_local',
);

has_field 'client_cert_path' => (
    type        => 'Path',
    required    => 0,
    tags        => { 
        after_element   => \&help,
        help            => 'Path of the client cert that will be used to generate the p12',
    },
);

has_field 'client_cert_path_upload' => (
   type => 'PathUpload',
   accessor => 'client_cert_path',
   config_prefix => '.crt',
   required => 0,
   upload_namespace => 'pki',
);

has_field 'client_key_path' => (
    type        => 'Path',
    required    => 0,
    tags        => {
        after_element   => \&help,
        help            => 'Path of the client key that will be used to generate the p12',
    },
);

has_field 'client_key_path_upload' => (
   type => 'PathUpload',
   accessor => 'client_key_path',
   config_prefix => '.key',
   required => 0,
   upload_namespace => 'pki',
);

has_field 'ca_cert_path' => (
    type        => 'Path',
    required    => 0,
    tags        => { 
        after_element   => \&help,
        help            => 'Path of the CA certificate used to generate client certificate/key combination',
    },
);

has_field 'ca_cert_path_upload' => (
   type => 'PathUpload',
   accessor => 'ca_cert_path',
   config_prefix => '.crt',
   required => 0,
   upload_namespace => 'pki',
);

has_field 'server_cert_path' => (
    type        => 'Path',
    required    => 0,
    tags        => { 
        after_element   => \&help,
        help            => 'Path of the RADIUS server authentication certificate',
    },
);

has_field 'server_cert_path_upload' => (
   type => 'PathUpload',
   accessor => 'server_cert_path',
   config_prefix => '.crt',
   required => 0,
   upload_namespace => 'pki',
);

has_block 'definition' => (
    render_list => [ qw(type client_cert_path client_key_path ca_cert_path server_cert_path) ],
);

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

__PACKAGE__->meta->make_immutable unless $ENV{"PF_SKIP_MAKE_IMMUTABLE"};

1;
