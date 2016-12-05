package pfappserver::Form::Config::Domain;

=head1 NAME

pfappserver::Form::Config::Domain - Web form for domains

=head1 DESCRIPTION

Form definition to create or update domains.

=cut

use HTML::FormHandler::Moose;
extends 'pfappserver::Base::Form';
with 'pfappserver::Base::Form::Role::Help';

use pf::log;
use pf::config;
use pf::util;
use pf::authentication;

## Definition
has_field 'id' =>
  (
   type => 'Text',
   label => 'Identifier',
   required => 1,
   maxlength => 10,
   messages => { required => 'Please specify an identifier' },
   tags => { after_element => \&help,
             help => 'Specify a unique identifier for your configuration.<br/>This doesn\'t have to be related to your domain' },
   apply => [ pfappserver::Base::Form::id_validator('identifier') ]
  );

has_field 'workgroup' =>
  (
   type => 'Text',
   label => 'Workgroup',
   required => 1,
   messages => { required => 'Please specify the workgroup' },
  );

has_field 'ad_server' =>
  (
   type => 'Text',
   label => 'Active Directory server',
   required => 1,
   messages => { required => 'Please specify the Active Directory server' },
   tags => { after_element => \&help,
             help => 'The IP address or DNS name of your Active Directory server' },
  );

has_field 'bind_pass' =>
  (
   type => 'Password',
   label => 'Password',
   tags => { after_element => \&help,
             help => 'The password of a Domain Admin to use to join the server to the domain. Will not be stored permanently and is only used while joining the domain.' },
  );

has_field 'bind_dn' =>
  (
   type => 'Text',
   label => 'Username',
   tags => { after_element => \&help,
             help => 'The username of a Domain Admin to use to join the server to the domain' },
  );

has_field 'dns_server' =>
  (
   type => 'IPAddress',
   label => 'DNS server',
   required => 1,
   messages => { required => 'Please specify the DNS server' },
   tags => { after_element => \&help,
             help => 'The IP address of the DNS server for this domain.' },
  );

has_field 'server_name' =>
  (
   type => 'Text',
   label => 'This server\'s name',
   default => '%h',
   required => 1,
   maxlength => 14,
   messages => { required => 'Please specify the server\'s name' },
   tags => { after_element => \&help,
             help => 'This server\'s name (account name) in your Active Directory. Use \'%h\' to automatically use this server hostname' },
  );

has_field 'dns_name' =>
  (
   type => 'Text',
   label => 'DNS name of the domain',
   required => 1,
   messages => { required => 'Please specify the DNS name of the domain' },
   tags => { after_element => \&help,
             help => 'The DNS name (FQDN) of the domain.' },
  );

has_field 'ou' => (
    type        => 'Text',
    label       => 'OU',
    default     => 'Computers',
    required    => 1,
    message     => { required => 'Please specify a OU in which the machine account will be created' },
    tags        => {
        after_element   => \&help,
        help            => 'Precreate the computer account in a specific OU. The OU string read from top to bottom without RDNs and delimited by a \'/\'. E.g. "Computers/Servers/Unix"',
    },
);

has_field 'registration' =>
  (
   type => 'Checkbox',
   label => 'Allow on registration',
   tags => { after_element => \&help,
             help => 'If this option is enabled, the device will be able to reach the Active Directory from the registration VLAN.' },
  );

has_field 'ntlm_cache' =>
  (
   type => 'Toggle',
   checkbox_value => "enabled",
   unchecked_value => "disabled",
   label => 'NTLM cache',
   tags => { after_element => \&help,
             help => 'Should the NTLM cache be enabled for this domain?' },
  );

has_field 'ntlm_cache_source' =>
  (
   type => 'Select',
   label => 'Source',
   tags => { after_element => \&help,
             help => 'The source to use to connect to your Active Directory server for NTLM caching.' },
   element_attr => {'data-placeholder' => 'Click to select a source'},
   multiple => 0,
   element_class => ['chzn-deselect'],
  );

has_field 'ntlm_cache_filter' =>
  (
   type => 'TextArea',
   label => 'LDAP filter',
   tags => { after_element => \&help,
             help => 'An LDAP query to filter out the users that should be cached.' },
   default => "(&(samAccountName=*)(!(|(lockoutTime=>0)(userAccountControl:1.2.840.113556.1.4.803:=2))))",
  );

has_field 'ntlm_cache_expiry' =>
  (
   type => 'PosInteger',
   label => 'Expiration',
   default => 3600,
   tags => { after_element => \&help,
             help => 'The amount of seconds an entry should be cached. This should be adjusted to twice the value of maintenance.populate_ntlm_redis_cache_interval' },
  );

has_block definition =>
  (
   render_list => [ qw(workgroup dns_name server_name ad_server dns_server bind_dn bind_pass ou registration) ],
  );

has_block ntlm_cache =>
  (
   render_list => [ qw(ntlm_cache ntlm_cache_source ntlm_cache_filter ntlm_cache_expiry) ],
  );

=head2 options_ntlm_cache_sources

The AD sources that can be selected for NTLM auth cache

=cut

sub options_ntlm_cache_source {
    my ($self) = @_;

    my @sources = map {$_->{id} => $_->{id}} @{pf::authentication::getAuthenticationSourcesByType("AD")};
    unshift @sources, ("" => "");
    return @sources;
}

=head2 validate

Validate NTLM cache fields if ntlm_cache is enabled

=cut

sub validate {
    my ($self) = @_;
    if(isenabled($self->field('ntlm_cache')->value())) {
        get_logger->info("Validating NTLM cache fields because it is enabled.");
        unless($self->field('ntlm_cache_source')->value) {
            $self->field("ntlm_cache_source")->add_error("A valid source must be selected when NTLM cache is enabled."); 
        }
        unless($self->field('ntlm_cache_filter')->value) {
            $self->field("ntlm_cache_filter")->add_error("An LDAP filter must be specified for caching when NTLM cache is enabled."); 
        }
        unless($self->field('ntlm_cache_expiry')->value) {
            $self->field("ntlm_cache_expiry")->add_error("An expiration must be specified for caching when NTLM cache is enabled."); 
        }
    }
}

=over

=back

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

__PACKAGE__->meta->make_immutable;
1;
