package pf::Authentication::Source::LDAPSource;
use pf::Authentication::Source;
use Moose;

use pf::config qw($TRUE $FALSE);
use pf::Authentication::Condition;
use Net::LDAP;

extends 'pf::Authentication::Source';

# available encryption
use constant {
        NONE => "none",
        SSL => "ssl",
	TLS => "tls",
      };

has 'host' => (isa => 'Str', is => 'rw', required => 1);
has 'port' => (isa => 'Int', is => 'rw', required => 1);
has 'basedn' => (isa => 'Str', is => 'rw', required => 1);
has 'binddn' => (isa => 'Str', is => 'rw', required => 1);
has 'password' => (isa => 'Str', is => 'rw', required => 1);
has 'encryption' => (isa => 'Str', is => 'rw', required => 1);
has 'scope' => (isa => 'Str', is => 'rw', required => 1);
has 'usernameattribute' => (isa => 'Str', is => 'rw', required => 1);

sub available_attributes {
  my $self = shift;
  my $super_attributes = $self->SUPER::available_attributes;
  my $ldap_attributes = ["cn", "department", "displayName", "distinguishedName", "memberOf", "sn"];
  
  # We check if our username attribute is present, if not we add it.
  if (not grep {$_ eq $self->{'usernameattribute'}} @$ldap_attributes ) {
    push (@$ldap_attributes, $self->{'usernameattribute'});
  }

  return [@$super_attributes, @$ldap_attributes];
}

sub authenticate {
  
  my ( $self, $username, $password ) = @_;
  
  my $connection = Net::LDAP->new($self->{'host'});
  
  if (! defined($connection)) {
    return ($FALSE, 'Unable to validate credentials at the moment');
  }

  my $result = $connection->bind($self->{'binddn'}, password => $self->{'password'});
  
  if ($result->is_error) {
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
    return ($FALSE, 'Unable to validate credentials at the moment');
  }
  
  if ($result->count != 1) {
    return ($FALSE, 'Invalid login or password');
  }
  
  my $user = $result->entry(0);
  
  $result = $connection->bind($user->dn, password => $password);
  
  if ($result->is_error) {
    return ($FALSE, 'Invalid login or password');
  }

  return ($TRUE, 'Successful authentication using LDAP.');
}

sub match {
  my ($self, $params) = @_;

  print "Matching in LDAP source...\n";

  my $rules = $self->SUPER::match($params);
  my $logger = Log::Log4perl->get_logger('pf::authentication');

  # FIXME: SUPPORT PORT, TLS/SSL
  my $connection = Net::LDAP->new($self->{'host'});
  if (! defined($connection)) {
    print "Unable to connect to '$self->{'host'}'\n";
    $logger->error("Unable to connect to '$self->{'host'}'");
    return $rules;
  }
  
  my $result = $connection->bind($self->{'binddn'}, password => $self->{'password'});
  
  if ($result->is_error) {
    print "Unable to bind with '$self->{'binddn'}'\n";
    $logger->error("Unable to bind with '$self->{'binddn'}'");
    return $rules;
  }
  
  my @matching_rules = ();

  print "About to match rules...\n";

  foreach my $rule ( @$rules ) {
    print "Checking rule\n";
    my $filter = ldap_filter_for_rule($rule, $self->{'usernameattribute'}, $params);
	
    print "Searching for $filter, from $self->{'basedn'}, with scope $self->{'scope'}\n";
    $result = $connection->search(
				  base => $self->{'basedn'},
				  filter => $filter,
				  scope => $self->{'scope'},
				  attrs => ['dn']
				 );
    
    if ($result->is_error) {
      $logger->error("Unable to execute search");
      next;
    }
    
    if ($result->count == 1) {
      my $dn = $result->entry(0)->dn;
      $connection->unbind;
      push(@matching_rules, $rule);
      return $rule->{'actions'};
    }
  }
  
  return @matching_rules;
}

=item ldap_filter_for_rule

This function is used to generate an LDAP filter based on condition
from a rule.

=cut
sub ldap_filter_for_rule {
  my ($rule, $usernameattribute, $params) = @_;

  my $expression = '(';
  
  if ($rule->match eq pf::Rule->ANY) {
    $expression .= '|';
  }
  else {
    $expression .= '&';
  }
  
  foreach my $condition (@{$rule->{'conditions'}})  {
    my $str;
    
    # FIXME - we should escape things properly
    if ($condition->{'operator'} eq Condition->EQUALS) {
      $str = "$condition->{'attribute'}=$condition->{'value'}";
    } elsif ($condition->{'operator'} eq Condition->CONTAINS) {
      $str = "$condition->{'attribute'}=*$condition->{'value'}*";
    }
    
    if (scalar @{$rule->{'conditions'}} == 1) {
      $expression = '(' . $str;
    }
    else {
      $expression .= '(' . $str . ')';
    }
  }

  $expression .= ')';
 
  $expression = "(&($usernameattribute=$params->{'username'})$expression)";
  
  print "Expression: $expression\n";

  return $expression;
} 

=back

=head1 COPYRIGHT

Copyright (C) 2012 Inverse inc.

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

# vim: set shiftwidth=4:
# vim: set expandtab:
# vim: set backspace=indent,eol,start:
