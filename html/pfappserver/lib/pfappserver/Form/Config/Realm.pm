package pfappserver::Form::Config::Realm;

=head1 NAME

pfappserver::Form::Config::Realm - Web form for a floating device

=head1 DESCRIPTION

Form definition to create or update realm.

=cut

use HTML::FormHandler::Moose;
extends 'pfappserver::Base::Form';
with 'pfappserver::Base::Form::Role::Help';

use pf::config;
use pf::authentication;
use pf::util;
use pf::ConfigStore::Domain;

has domains => ( is => 'rw', builder => '_build_domains');
tie our %ConfigAuthenticationLdap, 'pfconfig::cached_hash', 'resource::authentication_sources_ldap';

## Definition
has_field 'id' =>
  (
   type => 'Text',
   label => 'Realm',
   required => 1,
   messages => { required => 'Please specify a Realm' },
   apply => [ pfappserver::Base::Form::id_validator('realm') ]
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

has_field 'permit_userPrincipalName' =>
  (
   type => 'Toggle',
   checkbox_value => "enabled",
   unchecked_value => "disabled",
   default => "enabled",
   label => 'userPrincipalName',
   tags => { after_element => \&help,
             help => 'Allow userPrincipalName attribute to authenticate 802.1x users' },
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
             help => 'The LDAP Server to query the userPrincipalName' },
  );

=head2 options_roles

=cut

sub options_domains {
    my $self = shift;
    my @domains = map { $_->{id} => $_->{id} } @{$self->form->domains} if ($self->form->domains);
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

=over

=back

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

__PACKAGE__->meta->make_immutable unless $ENV{"PF_SKIP_MAKE_IMMUTABLE"};

1;
