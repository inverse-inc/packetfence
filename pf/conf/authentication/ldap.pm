package authentication::ldap;

=head1 NAME

authentication::ldap - LDAP authentication

=head1 DESCRIPTION

authentication::ldap allows to validate a username/password combination using LDAP

This module extends pf::web::auth

=cut
use strict;
use warnings;
use diagnostics;
use Log::Log4perl;
use Net::LDAP;

use base ('pf::web::auth');

use pf::config qw($TRUE $FALSE);

our $VERSION = 1.10;

=head1 CONFIGURATION AND ENVIRONMENT

Don't forget to install the Net::LDAP module. 
This is done automatically if you use a packaged version of PacketFence.

Define the variables C<LDAPServer>, C<LDAPBindDN>, C<LDAPBindPassword>, C<LDAPUserBase>, C<LDAPUserKey>
and C<LDAPUserScope> at the top of the module.

=over

=item * C<LDAPServer>

LDAPServer hostname of IP address to connect to

=item * C<LDAPBindDN> and C<LDAPBindPassword>

DN and password of a user which is allowed to search for user accounts

=item * C<LDAPUserKey> 

The name of the parameter you would like to find your users by (in order to retrieve their DN).

=item * C<LDAPUserBase>

LDAP branch your users are in

=item * C<LDAPUserScope>

Do you want to search the whole subbranch of $LDAPUserBase for users or only direct entries at $LDAPUserBase ?

=cut
my $LDAPUserBase = "";
my $LDAPUserKey = "cn";
my $LDAPUserScope = "sub";
my $LDAPBindDN = "";
my $LDAPBindPassword = "";
my $LDAPServer = "";
my $LDAPGroupMemberKey = "memberOf";
my $LDAPGroupDN = "";

=back

=head2 Optional

=over

=item name

Name displayed on the captive portal dropdown (displayed only if more than 1 auth type is configured).

=cut
our $name = "LDAP";

=back

=head1 TESTING

You can try your LDAP query with:

  ldapsearch -x -b <LDAPUserBase> -h <LDAPServer> -W -D <LDAPBindDN> <LDAPUserKey>=username dn

For example:

  ldapsearch -x -b "ou=users,dc=packetfence,dc=org" -h ldap.packetfence.org -W -D "cn=PacketFence,ou=IT,dc=packetfence,dc=org" "cn=obilodeau" dn

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

=head1 OBJECT METHODS

=over 

=item * authenticate ($login, $password)

True if successful, false otherwise. 
If unsuccessful errors meant for users are available in getLastError(). 
Errors meant for administrators are logged in F<logs/packetfence.log>.

=cut
sub authenticate {
  my ($this, $username, $password) = @_;
  my $logger = Log::Log4perl::get_logger('authentication::ldap');

  my $connection = Net::LDAP->new($LDAPServer);
  if (! defined($connection)) {
    $logger->error("Unable to connect to '$LDAPServer'");
    $this->_setLastError('Unable to validate credentials at the moment');
    return $FALSE;
  }

  my $result = $connection->bind($LDAPBindDN, password => $LDAPBindPassword);

  if ($result->is_error) {
    $logger->error("Unable to bind with '$LDAPBindDN'");
    $this->_setLastError('Unable to validate credentials at the moment');
    return $FALSE;
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
    $this->_setLastError('Unable to validate credentials at the moment');
    return $FALSE;
  }
  
  if ($result->count != 1) {
    $logger->warn("Unable to find user '$username'");
    $this->_setLastError('Invalid login or password');
    return $FALSE;
  }

  my $user = $result->entry(0);

  $result = $connection->bind($user->dn, password => $password);

  if ($result->is_error) {
    $logger->info("invalid password for $username");
    $this->_setLastError('Invalid login or password');
    return $FALSE;
  }
  
  $connection->unbind;
  return $TRUE;
}

=item * getMemberGroups

Returns a list of all groups' DN in a given group DN.

=cut
sub getMemberGroups {
    my ($this, $connection, $group_dn) = @_;

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

=back

=head1 AUTHOR

Olivier Bilodau <obilodeau@inverse.ca>

Dominik Gehl <dgehl@inverse.ca>

=head1 COPYRIGHT

Copyright (C) 2006-2011 Inverse inc.

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
