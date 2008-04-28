# Copyright 2008 Inverse groupe conseil
#
# See the enclosed file COPYING for license information (GPL).
# If you did not receive this file, see
# http://www.fsf.org/licensing/licenses/gpl.html
#

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

sub authenticate {
  my ($username, $password) = @_;
  my $htpasswd = new Apache::Htpasswd({
      passwdFile => "/usr/local/pf/conf/user.conf",
      ReadOnly   => 1});
  return $htpasswd->htCheckPassword($username, $password);
}

1;
