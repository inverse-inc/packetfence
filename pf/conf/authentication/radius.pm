# Copyright 2008 Utelisys Communications B.V.
# Copyright 2008 packetfence.org
#
# See the enclosed file COPYING for license information (GPL).
# If you did not receive this file, see
# http://www.fsf.org/licensing/licenses/gpl.html
#
# return (1,0) for successfull authentication
# return (0,2) for inability to check credentials
# return (0,1) for wrong login/password


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

my $RadiusServer = 'localhost';
my $RadiusSecret = 'testing123';

sub authenticate {
 my ($username, $password) = @_;
 my $radcheck;
 $radcheck = new Authen::Radius(
    Host => $RadiusServer, 
    Secret => $RadiusSecret);
 if ($radcheck->check_pwd($username, $password)) {
     return (1,0);
 } else {
     return (0,1);
 }
}

1;

