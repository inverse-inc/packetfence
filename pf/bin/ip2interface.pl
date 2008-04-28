#!/usr/bin/perl
#
# $Id: ip2interface.pl,v 1.2 2005/11/17 21:47:08 dgehl Exp $
#
# Copyright 2005 Dave Laporte <dave@laportestyle.org>
# Copyright 2005 Kevin Amorin <kev@amorin.org>
#
# See the enclosed file COPYING for license information (GPL).
# If you did not receive this file, see
# http://www.fsf.org/licensing/licenses/gpl.html.
#

use strict;
use warnings;

use lib '/usr/local/pf/lib'; 
use pf::config;
use pf::util;
use pf::services;

$| = 1;

while (<STDIN>) {
  chop $_;
#print $_;
  my $ip = ip2interface($_);
  if (isenabled($Config{'trapping'}{'redirlocal'}) && $ip ne "0.0.0.0") {
    print STDOUT $ip."\n";
  } else {
    print STDOUT "NULL"."\n";
  }
}
