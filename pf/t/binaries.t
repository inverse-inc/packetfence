#!/usr/bin/perl
=head1 NAME

binaries.t

=head1 DESCRIPTION

Compile check on perl binaries

=cut
use strict;
use warnings;

use Test::More;
use Test::NoWarnings;

use TestUtils qw(get_all_perl_binaries get_all_perl_cgi);

my @binaries = (
    get_all_perl_binaries(), 
    get_all_perl_cgi()
);

# all files + no warnings
plan tests => scalar @binaries * 1 + 1;

# TODO because of the 'hack' described below, we can only run these tests as root

foreach my $current_binary (@binaries) {
    # hack: removing setuid bit otherwise we can't run a compile test. see 'Switches On the "#!" Line' in perlsec 
    `chmod ug-s $current_binary` if ($current_binary eq '/usr/local/pf/bin/pfcmd');

    is( system("/usr/bin/perl -c $current_binary 2>&1"), 0, "$current_binary compiles" );

    # hack: putting back setuid bit. see above
    `chmod ug+s $current_binary` if ($current_binary eq '/usr/local/pf/bin/pfcmd');
}

=head1 AUTHOR

Dominik Ghel <dghel@inverse.ca>

Olivier Bilodeau <obilodeau@inverse.ca>
        
=head1 COPYRIGHT
        
Copyright (C) 2009-2012 Inverse inc.

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

