package pf::pfqueue::status_updater::dummy;

use strict;
use warnings;

use Moo;
extends "pf::pfqueue::status_updater";

our $SINGLETON_DUMMY;

sub singleton {
    my ($proto) = @_;
    if(!defined($SINGLETON_DUMMY)) {
        $SINGLETON_DUMMY = $proto->new;
    }
    return $SINGLETON_DUMMY;
}

1;
