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
use Sys::Hostname;

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
   type => 'ObfuscatedText',
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

has_field 'dns_servers' =>
  (
   type => 'IPAddresses',
   label => 'DNS server(s)',
   required => 1,
   messages => { required => 'Please specify the DNS server(s)' },
   tags => { after_element => \&help,
             help => 'The IP address(es) of the DNS server(s) for this domain. Comma delimited if multiple.' },
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
             help => 'This server\'s name (account name) in your Active Directory. Use \'%h\' to automatically use this server hostname. In a cluster, you must leave %h and ensure your hostnames are less than 14 characters.' },
  );

has_field 'sticky_dc' => (
    type        => 'Text',
    label       => 'Sticky DC',
    default     => '*',
    required    => 1,
    message     => { required => 'Please specify a DC to connect to. Use \'*\' to connect to any available DC' },
    tags       => {
        after_element   => \&help,
        help            => 'This is used to specify a sticky domain controller to connect to. If not specified, default \'*\' will be used to connect to any available domain controller',
    },
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
             help => 'The amount of seconds an entry should be cached. This should be adjusted to twice the value of maintenance.populate_ntlm_redis_cache_interval if using the batch mode.' },
  );

has_field 'ntlm_cache_batch' =>
  (
   type => 'Toggle',
   checkbox_value => "enabled",
   unchecked_value => "disabled",
   label => 'NTLM cache background job',
   default => "disabled",
   tags => { after_element => \&help,
             help => 'When this is enabled, all users matching the LDAP filter will be inserted in the cache via a background job (maintenance.populate_ntlm_redis_cache_interval controls the interval).' },
  );

has_field 'ntlm_cache_batch_one_at_a_time' =>
  (
   type => 'Toggle',
   checkbox_value => "enabled",
   unchecked_value => "disabled",
   label => 'NTLM cache background job individual fetch',
   default => "disabled",
   tags => { after_element => \&help,
             help => 'Whether or not to fetch users on your AD one by one instead of doing a single batch fetch. This is useful when your AD is loaded or experiencing issues during the sync. Note that this makes the batch job much longer and is about 4 times slower when enabled.' },
  );

has_field 'ntlm_cache_on_connection' =>
  (
   type => 'Toggle',
   checkbox_value => "enabled",
   unchecked_value => "disabled",
   label => 'NTLM cache on connection',
   default => "disabled",
   tags => { after_element => \&help,
             help => 'When this is enabled, an async job will cache the NTLM credentials of the user every time he connects.' },
  );

has_block definition =>
  (
   render_list => [ qw(workgroup dns_name server_name sticky_dc ad_server dns_servers bind_dn bind_pass ou registration) ],
  );

has_block ntlm_cache =>
  (
   render_list => [ qw(ntlm_cache ntlm_cache_source ntlm_cache_filter ntlm_cache_expiry ntlm_cache_batch ntlm_cache_batch_one_at_a_time ntlm_cache_on_connection) ],
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

    if(($self->field('id')->value() // '') !~ /^[0-9a-zA-Z]+$/) {
        $self->field('id')->add_error("The id is invalid. The id can only contain alphanumeric characters.");
    }

    if($self->field('server_name')->value() eq "%h") {
        my $hostname = [split(/\./,hostname())]->[0];
        if(length($hostname) > $self->field('server_name')->maxlength) {
            $self->field("server_name")->add_error("You have selected %h as the server name but this server hostname ($hostname) is longer than 14 characters. Please change the value or modify the hostname of your server to a name of 14 characters or less.");            
        }   
    }

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
