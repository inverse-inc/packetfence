package pf::Authentication::Source::OpenIDSource;

=head1 NAME

pf::Authentication::Source::OpenIDSource

=head1 DESCRIPTION

=cut

use pf::log;
use Moose;
use pf::config qw(%Config);
use pf::constants qw($TRUE $FALSE);
use pf::Authentication::constants;
use pf::person qw(person_modify);
extends 'pf::Authentication::Source::OAuthSource';
with 'pf::Authentication::CreateLocalAccountRole';

has '+type' => (default => 'OpenID');
has '+class' => (default => 'external');
has 'client_id' => (isa => 'Str', is => 'rw', required => 1);
has 'client_secret' => (isa => 'Str', is => 'rw', required => 1);
has 'site' => (isa => 'Str', is => 'rw');
has 'access_token_path' => (isa => 'Str', is => 'rw');
has 'authorize_path' => (isa => 'Str', is => 'rw');
has 'scope' => (isa => 'Str', is => 'rw', default => 'openid');
has 'protected_resource_url' => (isa => 'Str', is => 'rw');
has 'redirect_url' => (isa => 'Str', is => 'rw', required => 1, default => 'https://<hostname>/oauth2/callback');
has 'domains' => (isa => 'Str', is => 'rw', required => 1);
has 'username_attribute' => ( is => 'rw', default => 'email', isa => 'Str');
has 'person_mappings' => ( is => 'rw', default => sub { [] });

=head2 available_attributes

Add additional available attributes

=cut

sub available_attributes {
  my $self = shift;

  my $super_attributes = $self->SUPER::available_attributes;
  my @attributes = @{$Config{advanced}{openid_attributes} // []};
  my @radius_attributes = map { { value => $_, type => $Conditions::SUBSTRING, label => "OpenID::$_" } } @attributes;
  return [@$super_attributes, @radius_attributes];
}
=head2 dynamic_routing_module

Which module to use for DynamicRouting

=cut

sub dynamic_routing_module { 'Authentication::OAuth::OpenID' }

=head2 lookup_from_provider_info

lookup_from_provider_info

=cut

sub lookup_from_provider_info {
    my ($self, $pid, $info) = @_;
    my $person_info = $self->map_to_person($info);
    if ($person_info) {
        person_modify($pid, %$person_info);
    }

    return;
}

sub map_to_person {
    my ($self, $info) = @_;
    my $mappings = $self->person_mappings;
    if (@$mappings == 0) {
        return undef;
    }

    my %person;
    for my $mapping (@$mappings) {
        $person{$mapping->{person_field}} = $info->{$mapping->{openid_field}};
    }

    return \%person;
}

sub match_in_subclass {
    my ($self, $params, $rule, $own_conditions, $matching_conditions, $extra) = @_;
    my $username = $params->{$self->username_attribute};
    foreach my $condition (@{ $own_conditions }) {
        my $r = $self->match_condition($condition, $params);
        if ($r) {
            push(@{ $matching_conditions }, $condition);
        }
    }

    return ($username, undef);
}

sub map_from_person {
    my ($self, $person) = @_;
    my $mappings = $self->person_mappings;
    my %info = (
        $self->username_attribute => $person->{pid},
    );

    for my $mapping (@$mappings) {
        $info{$mapping->{openid_field}} = $person->{$mapping->{person_field}};
    }

    return \%info;
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

__PACKAGE__->meta->make_immutable unless $ENV{"PF_SKIP_MAKE_IMMUTABLE"};
1;

# vim: set shiftwidth=4:
# vim: set expandtab:
# vim: set backspace=indent,eol,start:
