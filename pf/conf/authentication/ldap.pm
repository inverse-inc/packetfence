# Copyright 2006-2008 Inverse groupe conseil
# 
# See the enclosed file COPYING for license information (GPL).
# If you did not receive this file, see
# http://www.fsf.org/licensing/licenses/gpl.html
#
# return (1,0) for successfull authentication
# return (0,2) for inability to check credentials
# return (0,1) for wrong login/password

package authentication::ldap;

use strict;
use warnings;

BEGIN {
  use Exporter ();
  our (@ISA, @EXPORT);
  @ISA    = qw(Exporter);
  @EXPORT = qw(authenticate);
}

use Net::LDAP;
use lib '/usr/local/pf/lib';
use pf::config;
use pf::util;

my $LDAPUserBase = "";
my $LDAPUserKey = "cn";
my $LDAPUserScope = "one";
my $LDAPBindDN = "";
my $LDAPBindPassword = "";
my $LDAPServer = "";

sub authenticate {
  my ($username, $password) = @_;

  my $connection = Net::LDAP->new($LDAPServer);
  if (! defined($connection)) {
    pflogger("Unable to connect to '$LDAPServer'", 1);
    return (0,2);
  }

  my $result = $connection->bind($LDAPBindDN, password => $LDAPBindPassword);

  if ($result->is_error) {
    pflogger("Unable to bind with '$LDAPBindDN'", 1);
    return (0,2);
  }
 
  $result = $connection->search(
    base => $LDAPUserBase,
    filter => "($LDAPUserKey=$username)",
    scope => $LDAPUserScope,
    #attrs => ['dn']
  );
  
  if ($result->is_error) {
    pflogger("Unable to execute search", 1);
    return (0,2);
  }
  
  if ($result->count != 1) {
    pflogger("Unable to find user '$username'", 1);
    return (0,1);
  }

  my $user = $result->entry(0);

  $result = $connection->bind($user->dn, password => $password);

  if ($result->is_error) {
    pflogger("invalid password for $username", 8);
    return (0,1);
  }
  
  $connection->unbind;
  return (1,0);
}

1;
