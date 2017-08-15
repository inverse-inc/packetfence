package pfappserver::Form::Config::Source::LDAP;

=head1 NAME

pfappserver::Form::Config::Source::LDAP - Web form for a LDAP user source

=head1 DESCRIPTION

Form definition to create or update a LDAP user source.

=cut

use pf::Authentication::Source::LDAPSource;
use HTML::FormHandler::Moose;
extends 'pfappserver::Form::Config::Source';
with 'pfappserver::Base::Form::Role::Help';

our $META = pf::Authentication::Source::LDAPSource->meta;


# Form fields
has_field 'host' =>
  (
   type => 'Text',
   label => 'Host',
   element_class => ['input-small'],
   element_attr => {'placeholder' => '127.0.0.1'},
   default => $META->get_attribute('host')->default,
  );
has_field 'port' =>
  (
   type => 'PosInteger',
   label => 'Port',
   element_class => ['input-mini'],
   element_attr => {'placeholder' => '389'},
   default => $META->get_attribute('port')->default,
  );
has_field 'connection_timeout' =>
  (
    type         => 'PosInteger',
    label        => 'Connection timeout',
    element_attr => {
        'placeholder' => $META->get_attribute('connection_timeout')->default
    },
    default => $META->get_attribute('connection_timeout')->default,
  );
has_field 'encryption' =>
  (
   type => 'Select',
   label => 'Encryption',
   options =>
   [
    { value => 'none', label => 'None' },
    { value => 'ssl', label => 'SSL' },
    { value => 'starttls', label => 'Start TLS' },
   ],
   required => 1,
   element_class => ['input-small'],
   default => 'none',
  );
has_field 'basedn' =>
  (
   type => 'Text',
   label => 'Base DN',
   required => 1,
   # Default value needed for creating dummy source
   default => '',
   element_class => ['span10'],
  );
has_field 'scope' =>
  (
   type => 'Select',
   label => 'Scope',
   required => 1,
   options =>
   [
    { value => 'base', label => 'Base Object' },
    { value => 'one', label => 'One-level' },
    { value => 'sub', label => 'Subtree' },
    { value => 'children', label => 'Children' },
   ],
   default => 'base',
  );
has_field 'usernameattribute' =>
  (
   type => 'Text',
   label => 'Username Attribute',
   required => 1,
   # Default value needed for creating dummy source
   default => '',
  );
has_field 'binddn' =>
  (
   type => 'Text',
   label => 'Bind DN',
   element_class => ['span10'],
   tags => { after_element => \&help,
             help => 'Leave this field empty if you want to perform an anonymous bind.' },
   # Default value needed for creating dummy source
   default => '',
  );
has_field 'password' =>
  (
   type => 'ObfuscatedText',
   label => 'Password',
   trim => undef,
   # Default value needed for creating dummy source
   default => '',
  );
has_field 'stripped_user_name' =>
  (
   type            => 'Toggle',
   checkbox_value  => 'yes',
   unchecked_value => 'no',
   default         => 'yes',
   label           => 'Use stripped username ',
   tags => { after_element => \&help,
             help => 'Use stripped username returned by RADIUS to test the following rules.' },
   default => $META->get_attribute('stripped_user_name')->default,
  );

has_field 'cache_match',
  (
   type => 'Toggle',
   label => 'Cache match',
   checkbox_value => '1',
   unchecked_value => '0',
   tags => { after_element => \&help,
             help => 'Will cache results of matching a rule' },
   default => $META->get_attribute('cache_match')->default,
  );

has_field 'email_attribute' => (
    type => 'Text',
    label => 'Email attribute',
    required => 0,
    default => $META->get_attribute('email_attribute')->default,
    tags => {
        after_element => \&help,
        help => 'LDAP attribute name that stores the email address against which the filter will match.',
    },
);

has_field 'realm' =>
  (
   type => 'Select',
   multiple => 1,
   label => 'Associated Realms',
   options_method => \&options_realm,
   element_class => ['chzn-deselect'],
   element_attr => {'data-placeholder' => 'Click to add a realm'},
   tags => { after_element => \&help,
             help => 'Realms that will be associated with this source' },
   default => '',
  );

=head2 validate

Make sure a password is specified when a bind DN is specified.

=cut

sub validate {
    my $self = shift;

    $self->SUPER::validate();

    if ($self->value->{binddn}) {
        unless ($self->value->{password}) {
            $self->field('password')->add_error('Please specify a password.');
        }
    }
}

=head2 options_realm

retrive the realms

=cut

sub options_realm {
    my ($self) = @_;
    my @roles = map { $_ => $_ } sort keys %pf::config::ConfigRealm;
    return @roles;
}

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

__PACKAGE__->meta->make_immutable unless $ENV{"PF_SKIP_MAKE_IMMUTABLE"};
1;
