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

Define the variables C<LDAPServer>, C<LDAPBindDN>, 
C<LDAPBindPassword>, C<LDAPUserBase>, C<LDAPUserKey>
and C<LDAPUserScope> at the top of the module.

=over

=item * C<LDAPServer>

LDAPServer hostname of IP address to connect to

=item * C<LDAPBindDN> and C<LDAPBindPassword>

DN and password of a user which is allowed to search for
user accounts

=item * C<LDAPUserKey> 

The name of the parameter you would like to find your users
by (in order to retrieve their DN).

=item * C<LDAPUserBase>

LDAP branch your users are in

=item * C<LDAPUserScope>

Do you want to search the whole subbranch of $LDAPUserBase 
for users or only direct entries at $LDAPUserBase ?

=back

=head1 TESTING

TODO you can try your LDAP query with:

=head1 EXAMPLES

Here's an example modification in order to test several 
LDAP servers:

  my @LDAPServers = ('ad1.example.com', 'ad2.example.com', 'ad3.example.com');

  sub authenticate {
    my ($username, $password) = @_;
    my $logger = Log::Log4perl::get_logger('authentication::ldap');

    my $connection = undef;
    my $i = 0;
    while ( ( $i < scalar(@LDAPServers) ) && ( !defined($connection) ) ) {
       $connection = Net::LDAP->new($LDAPServers[$i]);
       if (! defined($connection)) {
         $logger->warn("Unable to connect to '$LDAPServers[$i]'");
       }
    }

    if (! defined($connection)) {
       return (0,2);
    }

    [...]

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
#my $LDAPGroupMemberKey = "memberOf";
#my $LDAPGroupDN = "";

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
#    filter => "(&($LDAPUserKey=$username)($LDAPGroupMemberKey=$LDAPGroupDN))",
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

=item get_membergroups

Returns a list of all groups' DN in a given group DN.

=cut
sub get_membergroups {
    my ($connection, $group_dn) = @_;

    my $result = $connection->search(
        base => $LDAPUserBase,
        filter => "(&(objectClass=group)($LDAPGroupMemberKey=$group_dn))",
        scope => $LDAPUserScope,
        attrs => ['dn']
    );

    my @membergroups;
    foreach my $entry ($result->entries) {
        push @membergroups, $entry->dn();
    }
    return @membergroups;
}

=head1 DEPENDENCIES

=over

=item * Log::Log4perl

=item * Net::LDAP

=back

=head1 AUTHOR

Olivier Bilodau <obilodeau@inverse.ca>

Dominik Gehl <dgehl@inverse.ca>

=head1 COPYRIGHT

Copyright (C) 2006-2011 Inverse inc.

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
