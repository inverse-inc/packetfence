package pfappserver::Form::Config::Radiusd::EAPProfile;

=head1 NAME

pfappserver::Form::Config::Radiusd::EAPProfile -

=head1 DESCRIPTION

pfappserver::Form::Config::Radiusd::EAPProfile

=cut

use strict;
use warnings;
use HTML::FormHandler::Moose;
use pf::ConfigStore::Radiusd::TLSProfile;
use pf::ConfigStore::Radiusd::FastProfile;
use pf::ConfigStore::Radiusd::TeapProfile;
extends 'pfappserver::Base::Form';
with qw(pfappserver::Base::Form::Role::Help);
## Definition
has_field 'id' => (
    type     => 'Text',
    label    => 'Profile Name',
    required => 1,
    messages => { required => 'Please specify the name of the EAP profile.' },
);

has_field default_eap_type => (
    type     => 'Select',
    label    => 'Default EAP Type',
    options  => [
        map { { value => lc($_), label => $_ } }
          qw(GTC MD5 MSCHAPv2 LEAP PEAP FAST TLS TTLS TEAP)
    ],
);

has_field timer_expire => (
    type => 'Text',
);

for my $f (qw(ignore_unknown_eap_types cisco_accounting_username_bug)) {
    has_field $f => (
        type            => 'Toggle',
        checkbox_value  => 'yes',
        unchecked_value => 'no',
        default         => 'no',
    );
}

has_field 'max_sessions' => (
    type     => 'Text',
);

has_field eap_authentication_types => (
    type     => 'Select',
    multiple => 1,
    options  => [
        map { { value => $_, label => $_ } }
          qw(GTC MD5 MSCHAPv2 LEAP PEAP FAST TLS TTLS TEAP)
    ]
);

for my $f (qw(tls_tlsprofile ttls_tlsprofile peap_tlsprofile)) {
    has_field $f => (
        type => 'Select',
        options_method => \&options_tls,
    );
}

has_field fast_config => (
    type => 'Select',
    options_method => \&options_fast,
);

has_field teap_config => (
    type => 'Select',
    options_method => \&options_teap,
);

sub options_tls {
    return  map { { value => $_, label => $_ } } @{pf::ConfigStore::Radiusd::TLSProfile->new->readAllIds};
}

sub options_fast {
    return  map { { value => $_, label => $_ } } @{pf::ConfigStore::Radiusd::FastProfile->new->readAllIds};
}

sub options_teap {
    return  map { { value => $_, label => $_ } } @{pf::ConfigStore::Radiusd::TeapProfile->new->readAllIds};
}

=head2 validate

A method listed in eap_authentication_types is rendered into eap.conf from
its profile: an empty profile renders an invalid module block, which stops
every radiusd instance.

=cut

sub validate {
    my ($self) = @_;
    my $value = $self->value;
    my %enabled = map { $_ => 1 } @{ $value->{eap_authentication_types} // [] };
    for my $check ([TEAP => 'teap_config'], [FAST => 'fast_config']) {
        my ($type, $field) = @$check;
        next unless $enabled{$type};
        next if defined $value->{$field} && length $value->{$field};
        $self->field($field)->add_error("A $type profile is required when $type is in the EAP authentication types.");
    }
}

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

