#!/usr/bin/perl -w

use strict;
use warnings;
use diagnostics;

use lib '/usr/local/pf/lib';
use Test::More tests => 4;
use Test::Exception;
use File::Basename qw(basename);

Log::Log4perl->init("/usr/local/pf/t/log.conf");
my $logger = Log::Log4perl->get_logger( basename($0) );
Log::Log4perl::MDC->put( 'proc', basename($0) );
Log::Log4perl::MDC->put( 'tid',  0 );

BEGIN { use_ok('pf::nodecategory') }

# subs
can_ok('pf::nodecategory', qw(
    nodecategory_db_prepare
    nodecategory_view_all
    nodecategory_view
    nodecategory_view_by_name
    nodecategory_add
    nodecategory_modify
    nodecategory_delete
    nodecategory_exist
    nodecategory_lookup
));

throws_ok { nodecategory_add((notes => 'no-name')) } # passing an anonymous hash, forgetting the mandatory 'name'
    qr/name missing/,
    'nodecategory_add without a name parameter';

throws_ok { nodecategory_modify(1, (notes => 'no-name')) } # passing an anonymous hash, forgetting the mandatory 'name'
    qr/name missing/,
    'nodecategory_modify without a name parameter';
