# Copyright 2008 Inverse groupe conseil
#
# See the enclosed file COPYING for license information (GPL).
# If you did not receive this file, see
# http://www.fsf.org/licensing/licenses/gpl.html
#
# return (1,0) for successfull authentication
# return (0,2) for inability to check credentials
# return (0,1) for wrong login/password


package authentication::local;

use strict;
use warnings;

BEGIN {
  use Exporter ();
  our (@ISA, @EXPORT);
  @ISA    = qw(Exporter);
  @EXPORT = qw(authenticate);
}

use Apache::Htpasswd;
use Log::Log4perl;

use pf::config;
use pf::util;


sub authenticate {
  my ($username, $password) = @_;
  my $logger = Log::Log4perl::get_logger('authentication::local');
  my $passwdFile = "$conf_dir/user.conf";

  if (! -r $passwdFile) {
      $logger->error("unable to read password file '$passwdFile'");
      return (0,2);
  }

  my $htpasswd = new Apache::Htpasswd({
      passwdFile => $passwdFile,
      ReadOnly   => 1});
  if ($htpasswd->htCheckPassword($username, $password) == 0) {
      return (0,1);
  } else {
      return (1,0);
  }
}

1;
