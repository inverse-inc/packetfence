#!/usr/bin/perl
=head1 NAME

webauth.pl

=head1 DESCRIPTION

WARNING: The test doesn't run anymore because the pf::web::auth subsystem was reworked as a consequence of the results.

Some performance benchmarks on pf::web::auth object creation.

The goal was to see how we could avoid too much performance penality to do an eval'ed use ...::$auth_type.
We wanted to change the lifecycle of a pf::web::auth class so it would be created, 
used then throwed away instead of the current caching done by pf::web::auth class methods.

=head1 RESULTS

# ./webauth.pl
                Rate     eval_new   preuse_new get_instance
eval_new      2169/s           --         -83%         -85%
preuse_new   12658/s         484%           --         -10%
get_instance 14085/s         549%          11%           --

Given these results, we will pre-use the enabled auth modules and instatiate objects on every authentication.

=cut
use strict;
use warnings;
use diagnostics;

use Benchmark qw(cmpthese);
use Try::Tiny;

use lib '/usr/local/pf/lib';
use lib '/usr/local/pf/conf';

=head1 TESTS

=over

=cut
use pf::config;
use pf::web::auth;

our @supported_auth = qw(guest_managers kerberos ldap local preregistered_guests radius);

foreach my $auth_type (@supported_auth) { 
    eval "use authentication::$auth_type $AUTHENTICATION_API_LEVEL";
    die($@) if ($@);
}

=item Singleton, eval'ed auth + new and pre-eval'ed auth + new  comparison

=cut
cmpthese(10_000, {
    get_instance => sub { 

        foreach my $auth (@supported_auth) {
            my $authenticator = pf::web::auth::get_instance($auth);
            $authenticator->getName();
        }

    },

    'eval_new' => sub { 

        foreach my $auth_type (@supported_auth) { 
            eval "use authentication::$auth_type $AUTHENTICATION_API_LEVEL";
            die($@) if ($@);
            my $auth_obj = "authentication::$auth_type"->new();
            $auth_obj->getName();
        }
    },

    'preuse_new' => sub { 

        foreach my $auth_type (@supported_auth) { 
            my $auth_obj = "authentication::$auth_type"->new();
            $auth_obj->getName();
        }
    },

});

=head1 AUTHOR

Inverse inc. <info@inverse.ca>

=head1 COPYRIGHT

Copyright (C) 2005-2013 Inverse inc.

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
