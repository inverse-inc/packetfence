#!/usr/bin/perl
=head1 NAME

inline.t

=head1 DESCRIPTION

pf::inline module testing

=cut

use strict;
use warnings;
use diagnostics;

use lib '/usr/local/pf/lib';
BEGIN {
    use lib qw(/usr/local/pf/t);
    use setup_test_config;
}

use Test::More tests => 5;
use Test::MockModule;
use Test::MockObject::Extends;
use Test::NoWarnings;

use File::Basename qw(basename);

Log::Log4perl->init("log.conf");
my $logger = Log::Log4perl->get_logger( basename($0) );
Log::Log4perl::MDC->put( 'proc', basename($0) );
Log::Log4perl::MDC->put( 'tid',  0 );

use pf::config;

BEGIN { 
    use_ok('pf::inline'); 
    use_ok('pf::inline::custom');
}

# test the object
my $inline_obj = new pf::inline::custom();
isa_ok($inline_obj, 'pf::inline');

# subs
can_ok($inline_obj, qw(
    fetchMarkForNode 
    performInlineEnforcement
    isInlineEnforcementRequired
));

# TODO more tests!

=head1 AUTHOR

Inverse inc. <info@inverse.ca>

=head1 COPYRIGHT

Copyright (C) 2005-2019 Inverse inc.

=head1 LICENSE

This program is free software; you can redistribute it and/or
modify it under the terms of the GNU General Public License
as published by the Free Software Foundation; either version 2
of the License, or (at your option) any later version.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
GNU General Public License for more details.

You should have received a copy of the GNU General Public License
along with this program; if not, write to the Free Software
Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301,
USA.            

=cut

