# Copyright 2008 Utelisys Communications B.V.
# Copyright 2008 packetfence.org
#
# See the enclosed file COPYING for license information (GPL).
# If you did not receive this file, see
# http://www.fsf.org/licensing/licenses/gpl.html
#

package authentication::radius;

use strict;
use warnings;

BEGIN {
 use Exporter ();
 our (@ISA, @EXPORT);
 @ISA    = qw(Exporter);
 @EXPORT = qw(authenticate);
}

use Authen::Radius;

sub authenticate {
 my ($username, $password) = @_;
 my $radcheck;
 $radcheck = new Authen::Radius(
    Host => 'localhost', 
    Secret => 'testing123');
 return $radcheck->check_pwd($username, $password);
}

1;

