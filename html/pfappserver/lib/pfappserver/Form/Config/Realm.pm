package pfappserver::Form::Config::Realm;

=head1 NAME

pfappserver::Form::Config::Realm - Web form for a floating device

=head1 DESCRIPTION

Form definition to create or update realm.

=cut

use HTML::FormHandler::Moose;
extends 'pfappserver::Base::Form';
with 'pfappserver::Base::Form::Role::Help';

use pf::config qw(%ConfigAuthenticationAzureAD %ConfigAuthenticationLdap %ConfigEAP);
use pf::authentication;
use pf::util;
use pf::ConfigStore::Domain;

has domains => ( is => 'rw', builder => '_build_domains');

## Definition
has_field 'id' =>
  (
   type => 'Text',
   label => 'Realm',
   required => 1,
   messages => { required => 'Please specify a Realm' },
   apply => [ pfappserver::Base::Form::id_validator('realm') ],
   tags => {
      option_pattern => \&pfappserver::Base::Form::id_pattern,
   },
  );

has_field 'regex' =>
  (
   type => 'Text',
   label => 'Regex Realm',
   required => 0,
   tags => { after_element => \&help,
             help => 'PacketFence will use this Realm configuration if the regex match with the UserName (optional)' },
  );

has_field 'options' =>
  (
   type => 'TextArea',
   label => 'Realm Options',
   required => 0,
   tags => { after_element => \&help,
             help => 'You can add FreeRADIUS options in the realm definition' },
  );

has_field 'domain' =>
  (
   type => 'Select',
   multiple => 0,
   label => 'Domain',
   options_method => \&options_domains,
   element_class => ['chzn-deselect'],
   element_attr => {'data-placeholder' => 'Click to select a domain'},
   tags => { after_element => \&help,
             help => 'The domain to use for the authentication in that realm' },
  );

has_field 'radius_auth' =>
  (
   type => 'Select',
   multiple => 1,
   label => 'RADIUS AUTH',
   options_method => \&options_radius,
   element_class => ['chzn-select'],
   element_attr => {'data-placeholder' => 'Click to select a RADIUS Server'},
   tags => { after_element => \&help,
             help => 'The RADIUS Server(s) to proxy authentication' },
  );

has_field 'radius_auth_proxy_type' =>
  (
   type => 'Select',
   label => 'type',
   required => 1,
   options =>
   [
    { value => 'keyed-balance', label => 'Keyed Balance' },
    { value => 'fail-over', label => 'Fail Over' },
    { value => 'load-balance', label => 'Load Balance' },
    { value => 'client-balance', label => 'Client Balance' },
    { value => 'client-port-balance', label => 'Client Port Balance' },
   ],
   default => 'keyed-balance',
   tags => { after_element => \&help,
             help => 'Home server pool type' },
  );

  has_field 'radius_auth_compute_in_pf' =>
  (
   type => 'Toggle',
   checkbox_value => "enabled",
   unchecked_value => "disabled",
   default => "enabled",
   label => 'Authorize from PacketFence',
   tags => { after_element => \&help,
             help => 'Should we forward the request to PacketFence to have a dynamic answer or do we use the remote proxy server answered attributes ?' },
  );

has_field 'radius_acct' =>
  (
   type => 'Select',
   multiple => 1,
   label => 'RADIUS ACCT',
   options_method => \&options_radius,
   element_class => ['chzn-select'],
   element_attr => {'data-placeholder' => 'Click to select a RADIUS Server'},
   tags => { after_element => \&help,
             help => 'The RADIUS Server(s) to proxy accounting' },
  );

has_field 'radius_acct_proxy_type' =>
  (
   type => 'Select',
   label => 'type',
   required => 1,
   options =>
   [
    { value => 'keyed-balance', label => 'Keyed Balance' },
    { value => 'fail-over', label => 'Fail Over' },
    { value => 'load-balance', label => 'Load Balance' },
    { value => 'client-balance', label => 'Client Balance' },
    { value => 'client-port-balance', label => 'Client Port Balance' },
   ],
   default => 'load-balance',
   tags => { after_element => \&help,
             help => 'Home server pool type' },
  );

has_field 'eduroam_options' =>
  (
   type => 'TextArea',
   label => 'Eduroam Realm Options',
   required => 0,
   tags => { after_element => \&help,
             help => 'You can add FreeRADIUS options in the realm definition' },
  );

has_field 'eduroam_radius_auth' =>
  (
   type => 'Select',
   multiple => 1,
   label => 'Eduroam RADIUS AUTH',
   options_method => \&options_radius,
   element_class => ['chzn-select'],
   element_attr => {'data-placeholder' => 'Click to select a RADIUS Server'},
   tags => { after_element => \&help,
             help => 'The RADIUS Server(s) to proxy authentication' },
  );

has_field 'eduroam_radius_auth_proxy_type' =>
  (
   type => 'Select',
   label => 'type',
   required => 1,
   options =>
   [
    { value => 'keyed-balance', label => 'Keyed Balance' },
    { value => 'fail-over', label => 'Fail Over' },
    { value => 'load-balance', label => 'Load Balance' },
    { value => 'client-balance', label => 'Client Balance' },
    { value => 'client-port-balance', label => 'Client Port Balance' },
   ],
   default => 'keyed-balance',
   tags => { after_element => \&help,
             help => 'Home server pool type' },
  );

  has_field 'eduroam_radius_auth_compute_in_pf' =>
  (
   type => 'Toggle',
   checkbox_value => "enabled",
   unchecked_value => "disabled",
   default => "enabled",
   label => 'Authorize from PacketFence',
   tags => { after_element => \&help,
             help => 'Should we forward the request to PacketFence to have a dynamic answer or do we use the remote proxy server answered attributes ?' },
  );

has_field 'eduroam_radius_acct' =>
  (
   type => 'Select',
   multiple => 1,
   label => 'Eduroam RADIUS ACCT',
   options_method => \&options_radius,
   element_class => ['chzn-select'],
   element_attr => {'data-placeholder' => 'Click to select a RADIUS Server'},
   tags => { after_element => \&help,
             help => 'The RADIUS Server(s) to proxy accounting' },
  );

has_field 'eduroam_radius_acct_proxy_type' =>
  (
   type => 'Select',
   label => 'type',
   required => 1,
   options =>
   [
    { value => 'keyed-balance', label => 'Keyed Balance' },
    { value => 'fail-over', label => 'Fail Over' },
    { value => 'load-balance', label => 'Load Balance' },
    { value => 'client-balance', label => 'Client Balance' },
    { value => 'client-port-balance', label => 'Client Port Balance' },
   ],
   default => 'load-balance',
   tags => { after_element => \&help,
             help => 'Home server pool type' },
  );

has_field 'radius_strip_username' =>
  (
   type => 'Toggle',
   checkbox_value => "enabled",
   unchecked_value => "disabled",
   default => "enabled",
   label => 'Strip in RADIUS authorization',
   tags => { after_element => \&help,
             help => 'Should the usernames matching this realm be stripped when used in the authorization phase of 802.1x. Note that this doesn\'t control the stripping in FreeRADIUS, use the options above for that.' },
  );

has_field 'portal_strip_username' =>
  (
   type => 'Toggle',
   checkbox_value => "enabled",
   unchecked_value => "disabled",
   default => "enabled",
   label => 'Strip on the portal',
   tags => { after_element => \&help,
             help => 'Should the usernames matching this realm be stripped when used on the captive portal' },
  );

has_field 'admin_strip_username' =>
  (
   type => 'Toggle',
   checkbox_value => "enabled",
   unchecked_value => "disabled",
   default => "enabled",
   label => 'Strip on the admin',
   tags => { after_element => \&help,
             help => 'Should the usernames matching this realm be stripped when used on the administration interface' },
  );

has_field 'permit_custom_attributes' =>
  (
   type => 'Toggle',
   checkbox_value => "enabled",
   unchecked_value => "disabled",
   default => "disabled",
   label => 'Custom attributes',
   tags => { after_element => \&help,
             help => 'Allow to use custom attributes to authenticate 802.1x users (attributes are defined in the source)' },
  );

has_field 'ldap_source' =>
  (
   type => 'Select',
   multiple => 0,
   label => 'LDAP Source',
   options_method => \&options_ldap,
   element_class => ['chzn-select'],
   element_attr => {'data-placeholder' => 'Click to select a LDAP Server'},
   tags => { after_element => \&help,
             help => 'The LDAP Server to query the custom attributes' },
  );

has_field 'eap' =>
  (
   type => 'Select',
   multiple => 0,
   label => 'EAP',
   default => "default",
   options_method => \&options_eap,
   element_class => ['chzn-deselect'],
   element_attr => {'data-placeholder' => 'Click to select a eap configuration'},
   tags => { after_element => \&help,
             help => 'The EAP configuration to use for this realm' },
  );

has_field 'ldap_source_ttls_pap' =>
  (
   type => 'Select',
   multiple => 0,
   label => 'LDAP Source for TTLS PAP',
   options_method => \&options_ldap,
   element_class => ['chzn-select'],
   element_attr => {'data-placeholder' => 'Click to select an LDAP Server'},
   tags => { after_element => \&help,
             help => 'The LDAP Server to use for EAP TTLS PAP authentication and authorization' },
  );

has_field 'azuread_source_ttls_pap' =>
  (
   type => 'Select',
   multiple => 0,
   options_method => \&options_azuread,
  );

has_field 'edir_source' =>
  (
   type => 'Select',
   multiple => 0,
   label => 'eDirectory Source for PEAP',
   options_method => \&options_edir,
   element_class => ['chzn-select'],
   element_attr => {'data-placeholder' => 'Click to select an eDirectory Server'},
   tags => { after_element => \&help,
             help => 'The eDirectory Server to use for EAP PEAP authentication and authorization' },
  );

=head2 options_domains

=cut

sub options_domains {
    my $self = shift;
    my %e;
    map {
        my $id;
        if ($_->{id} =~ /^\S+\s+(\S+)$/) {
            $id = $1
        }
        else {
            $id = $_->{$id}
        }
        $e{$id} = 1
    } @{$self->form->domains} if ($self->form->domains);

    my @domains = map {$_ => $_} keys(%e);
    unshift @domains, ("" => "");
    return @domains;
}

sub _build_domains {
    my ($self) = @_;
    my $cs = pf::ConfigStore::Domain->new;
    return $cs->readAll("id");
}

=head2 options_ldap

=cut

sub options_ldap {
    my $self = shift;
    my @ldap = map { $_ => $_ } keys %ConfigAuthenticationLdap;
    unshift @ldap, ("" => "");
    return @ldap;
}

=head2 options_azuread

=cut

sub options_azuread {
    my $self = shift;
    my @sources = map { $_ => $_ } keys %ConfigAuthenticationAzureAD;
    unshift @sources, ("" => "");
    return @sources;
}

=head2 options_radius

=cut

sub options_radius {
    my $self = shift;
    my @radius = map { $_ => $_ } keys %pf::config::ConfigAuthenticationRadius;
    push @radius , map { $_ => $_ } keys %pf::config::ConfigAuthenticationEduroam;
    return @radius;
}

=head2 options_eap

=cut

sub options_eap {
    my $self = shift;
    my @eap = map { $_ => $_ } keys %ConfigEAP;
    return @eap;
}

=head2 options_edir

=cut

sub options_edir {
    my $self = shift;
    my @edir = map { $_ => $_ } keys %pf::config::ConfigAuthenticationEdir;
    return @edir;
}

=over

=back

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
