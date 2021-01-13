package pf::UnifiedApi::Controller::Config::PkiProviders;

=head1 NAME

pf::UnifiedApi::Controller::Config::PkiProviders - 

=cut

=head1 DESCRIPTION

pf::UnifiedApi::Controller::Config::PkiProviders

=cut

use strict;
use warnings;


use Mojo::Base qw(pf::UnifiedApi::Controller::Config::Subtype);

has 'config_store_class' => 'pf::ConfigStore::PKI_Provider';
has 'form_class' => 'pfappserver::Form::Config::PKI_Provider';
has 'primary_key' => 'pki_provider_id';

use pf::ConfigStore::PKI_Provider;
use pfappserver::Form::Config::PKI_Provider::packetfence_local;
use pfappserver::Form::Config::PKI_Provider::scep;
use pfappserver::Form::Config::PKI_Provider::packetfence_pki;

our %TYPES_TO_FORMS = (
    map { $_ => "pfappserver::Form::Config::PKI_Provider::$_" } qw(
        packetfence_local
        scep
        packetfence_pki
    )
);

sub type_lookup {
    return \%TYPES_TO_FORMS;
}

=head1 AUTHOR

Inverse inc. <info@inverse.ca>

=head1 COPYRIGHT

Copyright (C) 2005-2021 Inverse inc.

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

