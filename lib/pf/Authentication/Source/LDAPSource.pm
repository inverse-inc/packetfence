package pf::Authentication::Source::LDAPSource;

=head1 NAME

pf::Authentication::Source::LDAPSource

=head1 DESCRIPTION

=cut

use pf::config qw($TRUE $FALSE);
use pf::Authentication::constants;
use pf::Authentication::Condition;

use Net::LDAP;

use Moose;
extends 'pf::Authentication::Source';

# available encryption
use constant {
    NONE => "none",
    SSL => "ssl",
    TLS => "tls",
};

has '+type' => (default => 'LDAP');
has 'host' => (isa => 'Maybe[Str]', is => 'rw', default => '127.0.0.1');
has 'port' => (isa => 'Maybe[Int]', is => 'rw', default => 389);
has 'basedn' => (isa => 'Str', is => 'rw', required => 1);
has 'binddn' => (isa => 'Str', is => 'rw', required => 1);
has 'password' => (isa => 'Str', is => 'rw', required => 1);
has 'encryption' => (isa => 'Str', is => 'rw', required => 1);
has 'scope' => (isa => 'Str', is => 'rw', required => 1);
has 'usernameattribute' => (isa => 'Str', is => 'rw', required => 1);

=head1 METHODS

=head2 available_attributes

=cut

sub available_attributes {
  my $self = shift;

  my $super_attributes = $self->SUPER::available_attributes;
  my @ldap_attributes = map { { value => $_, type => $Conditions::STRING } }
    ("cn", "department", "displayName", "distinguishedName", "givenName", "memberOf", "sn");

  # We check if our username attribute is present, if not we add it.
  if (not grep {$_->{value} eq $self->usernameattribute} @ldap_attributes ) {
    push (@ldap_attributes, { value => $self->{usernameattribute}, type => $Conditions::STRING });
  }

  return [@$super_attributes, @ldap_attributes];
}

=head2 authenticate

=cut

sub authenticate {
  my ( $self, $username, $password ) = @_;
  my $logger = Log::Log4perl->get_logger( __PACKAGE__ );
  my $connection = Net::LDAP->new($self->{'host'});

  if (! defined($connection)) {
    $logger->info("Unable to establish LDAP connection.");
    return ($FALSE, 'Unable to validate credentials at the moment');
  }

  my $result = $connection->bind($self->{'binddn'}, password => $self->{'password'});

  if ($result->is_error) {
    $logger->info("Invalid LDAP credentials.");
    return ($FALSE, 'Unable to validate credentials at the moment');
  }

  my $filter = "($self->{'usernameattribute'}=$username)";
  $result = $connection->search(
    base => $self->{'basedn'},
    filter => $filter,
    scope => $self->{'scope'},
    attrs => ['dn']
  );
  if ($result->is_error) {
    $logger->info("Invalid LDAP search query ($filter).");      
    return ($FALSE, 'Unable to validate credentials at the moment');
  }

  if ($result->count != 1) {
    $logger->info("Invalid LDAP search response.");
    return ($FALSE, 'Invalid login or password');
  }

  my $user = $result->entry(0);

  $result = $connection->bind($user->dn, password => $password);

  if ($result->is_error) {
    return ($FALSE, 'Invalid login or password');
  }

  return ($TRUE, 'Successful authentication using LDAP.');
}

=head2 match_in_subclass

=cut

sub match_in_subclass {

    my ($self, $params, $rule, $own_conditions, $matching_conditions) = @_;

    my $logger = Log::Log4perl->get_logger( __PACKAGE__ );

    $logger->info("Matching rules in LDAP source.");

    my $filter = ldap_filter_for_conditions($own_conditions, $rule->match, $self->{'usernameattribute'}, $params);

    $logger->info("LDAP filter: $filter");

    my $connection = Net::LDAP->new($self->{'host'});
    if (! defined($connection)) {
        $logger->error("Unable to connect to '$self->{'host'}'");
        return undef;
    }

    my $result = $connection->bind($self->{'binddn'}, password => $self->{'password'});

    if ($result->is_error) {
        $logger->error("Unable to bind with '$self->{'binddn'}'");
        return undef;
    }

    $logger->info("Searching for $filter, from $self->{'basedn'}, with scope $self->{'scope'}");
    $result = $connection->search(
      base => $self->{'basedn'},
      filter => $filter,
      scope => $self->{'scope'},
      attrs => ['dn']
    );

    if ($result->is_error) {
        $logger->error("Unable to execute search, we skip the rule.");
        next;
    }

    if ($result->count == 1) {
        my $dn = $result->entry(0)->dn;
        $connection->unbind;
        $logger->info("Found a match ($dn)! pushing LDAP conditions");
        push @{ $matching_conditions }, @{ $own_conditions };
    }

    return undef;
}

=head2 test

Test if we can bind and search to the LDAP server

=cut

sub test {
  my ($self) = @_;
  my $logger = Log::Log4perl->get_logger( __PACKAGE__ );

  # Connect
  my $connection = Net::LDAP->new($self->{'host'});

  if (! defined($connection)) {
    $logger->info("Unable to establish LDAP connection.");
    return ($FALSE, "Can't connect to server");
  }

  # Bind
  my $result = $connection->bind($self->{'binddn'}, password => $self->{'password'});

  if ($result->is_error) {
    $logger->info("Invalid LDAP credentials.");
    return ($FALSE, 'Wrong bind DN or password');
  }

  # Search
  my $filter = "($self->{'usernameattribute'}=packetfence)";
  $result = $connection->search(
    base => $self->{'basedn'},
    filter => $filter,
    scope => $self->{'scope'},
    attrs => ['dn'],
    sizelimit => 1
  );

  if ($result->is_error) {
    $logger->info("Invalid LDAP search query ($filter).");
    return ($FALSE, 'Wrong base DN or username attribute');
  }

  return ($TRUE, 'Success');
}

=head2 ldap_filter_for_conditions

This function is used to generate an LDAP filter based on conditions
from a rule.

=cut

sub ldap_filter_for_conditions {
  my ($conditions, $match, $usernameattribute, $params) = @_;

  my $expression = '(';

  if ($match eq $Rules::ANY) {
    $expression .= '|';
  }
  else {
    $expression .= '&';
  }

  foreach my $condition (@{$conditions})  {
    my $str = "";

    # FIXME - we should escape things properly
    if ($condition->{'operator'} eq $Conditions::EQUALS) {
      $str = "$condition->{'attribute'}=$condition->{'value'}";
    } elsif ($condition->{'operator'} eq $Conditions::CONTAINS) {
      $str = "$condition->{'attribute'}=*$condition->{'value'}*";
    }

    if (scalar @{$conditions}  == 1) {
      $expression = '(' . $str;
    }
    else {
      $expression .= '(' . $str . ')';
    }
  }

  $expression .= ')';

  $expression = '(&(' . $usernameattribute . '=' . $params->{'username'} . ')' . $expression .')';

  return $expression;
}

=head2 username_from_email

=cut

sub username_from_email {
    my ( $self, $email ) = @_;

    my $logger = Log::Log4perl->get_logger('pf::authentication');

    my $filter = "(mail=$email)";

    my $connection = Net::LDAP->new($self->{'host'});
    if (! defined($connection)) {
      $logger->error("Unable to connect to '$self->{'host'}'");
      return undef;
    }

    my $result = $connection->bind($self->{'binddn'}, password => $self->{'password'});

    if ($result->is_error) {
      $logger->error("Unable to bind with '$self->{'binddn'}'");
      return undef;
    }

    $logger->info("Searching for $filter, from $self->{'basedn'}, with scope $self->{'scope'}");
    $result = $connection->search(
      base => $self->{'basedn'},
      filter => $filter,
      scope => $self->{'scope'},
      attrs => $self->{'usernameattribute'}
    );

    if ($result->is_error) {
      $logger->error("Unable to execute search, we skip the rule.");
      next;
    }

    if ($result->count == 1) {
      my $username = $result->entry->get_value( $self->{'usernameattribute'} );
      $connection->unbind;
      $logger->info("LDAP:found a match in username_from_email ($username)");
      return $username;
    }

    $logger->info("No match found for filter: $filter");
    return undef;
}

=head1 AUTHOR

Inverse inc. <info@inverse.ca>

=head1 COPYRIGHT

Copyright (C) 2005-2013 Inverse inc.

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

# vim: set shiftwidth=4:
# vim: set expandtab:
# vim: set backspace=indent,eol,start:
