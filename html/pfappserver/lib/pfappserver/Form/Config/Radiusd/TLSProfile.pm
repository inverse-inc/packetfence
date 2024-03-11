package pfappserver::Form::Config::Radiusd::TLSProfile;

=head1 NAME

pfappserver::Form::Config::Radiusd::TLSProfile -

=head1 DESCRIPTION

pfappserver::Form::Config::Radiusd::TLSProfile

=cut

use strict;
use warnings;
use HTML::FormHandler::Moose;
use pf::ConfigStore::Radiusd::OCSPProfile;
use pf::ConfigStore::SSLCertificate;
use pf::radius::constants;
extends 'pfappserver::Base::Form';
with qw(pfappserver::Base::Form::Role::Help);
## Definition
has_field 'id' =>
  (
   type => 'Text',
   label => 'Profile Name',
   required => 1,
   messages => { required => 'Please specify the name of the tls profile.' },
  );

has_field certificate_profile => (
    type => 'Select',
    options_method => \&options_certificate_profile,
);

has_field dh_file => (
    type => 'Text',
);

has_field ca_path => (
    type => 'Text',
);

has_field cipher_list => (
    type => 'Text',
);

has_field ecdh_curve => (
    type => 'Text',
);

has_field ocsp => (
    type => 'Select',
    options_method => \&options_ocsp,
);

has_field disable_tlsv1_2 => (
        type            => 'Toggle',
        checkbox_value  => 'yes',
        unchecked_value => 'no',
        default         => 'no',
);

has_field tls_min_version => (
    type => 'Select',
    options_method => \&options_tls_version,
);

has_field tls_max_version => (
    type => 'Select',
    options_method => \&options_tls_version,
);


sub options_certificate_profile {
    return  map { { value => $_, label => $_ } } @{pf::ConfigStore::SSLCertificate->new->readAllIds};
}

sub options_ocsp {
    return  map { { value => $_, label => $_ } } @{pf::ConfigStore::Radiusd::OCSPProfile->new->readAllIds};
}

sub options_tls_version {
    return map { { value => $_, label => $_ } } @{RADIUS::TLS_VERSIONS};
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
