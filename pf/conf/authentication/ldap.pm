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
    return 0;
  }

  my $result = $connection->bind($LDAPBindDN, password => $LDAPBindPassword);

  if ($result->is_error) {
    pflogger("Unable to bind with '$LDAPBindDN'", 1);
    return 0;
  }
 
  $result = $connection->search(
    base => $LDAPUserBase,
    filter => "($LDAPUserKey=$username)",
    scope => $LDAPUserScope,
    #attrs => ['dn']
  );
  
  if ($result->is_error) {
    pflogger("Unable to execute search", 1);
    return 0;
  }
  
  if ($result->count != 1) {
    pflogger("Unable to find user '$username'", 1);
    return 0;
  }

  my $user = $result->entry(0);

  $result = $connection->bind($user->dn, password => $password);

  if ($result->is_error) {
    pflogger("invalid password for $username", 8);
    return 0;
  }
  
  $connection->unbind;
  return 1;
}

1;
