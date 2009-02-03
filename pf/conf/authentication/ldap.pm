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
use Log::Log4perl;

use pf::config;
use pf::util;

my $LDAPUserBase = "";
my $LDAPUserKey = "cn";
my $LDAPUserScope = "sub";
my $LDAPBindDN = "";
my $LDAPBindPassword = "";
my $LDAPServer = "";

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

1;
