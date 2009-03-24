package authentication::ldap;

=head1 NAME

authentication::ldap - LDAP authentication

=head1 SYNOPSYS

  use authentication::ldap;
  my ( $authReturn, $err ) = authenticate ( 
                                 $login, 
                                 $password 
                                           );

=head1 DESCRIPTION

authentication::ldap allows to validate a username/password
combination using LDAP

=head1 CONFIGURATION AND ENVIRONMENT

Define the variables C<LDAPUserBase>, C<LDAPUserKey>, 
C<LDAPUserScope>, C<LDAPBindDN>, C<LDAPBindPassword>
and C<LDAPServer> at the top of the module.

=cut

use strict;
use warnings;
use diagnostics;

BEGIN {
  use Exporter ();
  our (@ISA, @EXPORT);
  @ISA    = qw(Exporter);
  @EXPORT = qw(authenticate);
}

use Net::LDAP;
use Log::Log4perl;

my $LDAPUserBase = "";
my $LDAPUserKey = "cn";
my $LDAPUserScope = "sub";
my $LDAPBindDN = "";
my $LDAPBindPassword = "";
my $LDAPServer = "";

=head1 SUBROUTINES

=over 

=item * authenticate ($login, $password)

  return (1,0) for successfull authentication
  return (0,2) for inability to check credentials
  return (0,1) for wrong login/password

=back

=cut

sub authenticate {
  my ($username, $password) = @_;
  my $logger = Log::Log4perl::get_logger('authentication::ldap');

  my $connection = Net::LDAP->new($LDAPServer);
  if (! defined($connection)) {
    $logger->error("Unable to connect to '$LDAPServer'");
    return (0,2);
  }

  my $result = $connection->bind($LDAPBindDN, password => $LDAPBindPassword);

  if ($result->is_error) {
    $logger->error("Unable to bind with '$LDAPBindDN'");
    return (0,2);
  }
 
  $result = $connection->search(
    base => $LDAPUserBase,
    filter => "($LDAPUserKey=$username)",
    scope => $LDAPUserScope,
    #attrs => ['dn']
  );
  
  if ($result->is_error) {
    $logger->error("Unable to execute search");
    return (0,2);
  }
  
  if ($result->count != 1) {
    $logger->warn("Unable to find user '$username'");
    return (0,1);
  }

  my $user = $result->entry(0);

  $result = $connection->bind($user->dn, password => $password);

  if ($result->is_error) {
    $logger->info("invalid password for $username");
    return (0,1);
  }
  
  $connection->unbind;
  return (1,0);
}

=head1 DEPENDENCIES

=over

=item * Log::Log4perl

=item * Net::LDAP

=back

=head1 AUTHOR

Dominik Gehl <dgehl@inverse.ca>

=head1 COPYRIGHT

Copyright (C) 2006-2008 Inverse groupe conseil

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
