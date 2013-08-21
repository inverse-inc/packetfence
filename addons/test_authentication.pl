#!/usr/bin/perl
=head1 NAME

test_authenticate add documentation

=cut

=head1 DESCRIPTION

test_authenticate

=cut

use strict;
use warnings;
use constant INSTALL_DIR => '/usr/local/pf';

use lib INSTALL_DIR . "/lib";
use pf::authentication;

my ($user,$pass) = @ARGV;

foreach my $source (@authentication_sources) {
    print "Authenticating user $user against " . $source->id . "\n";
    my ($result,$message) = $source->authenticate($user,$pass);
    $message = '' unless defined $message;
    if ($result) {
        print "User $user authentication succeeded against ",$source->id," ($message) \n";
    } else {
        print "User $user authentication failed against ",$source->id," ($message) \n";
    }
    my $actions;
    if( $actions = pf::authentication::match([$source], {username => $user})) {
        print "User $user matched against ",$source->id,"\n";
        if(ref($actions)) {
            foreach my $action (@$actions) {
                print $action->type," : ",$action->value,"\n";
            }
        }
    } else {
        print "User $user did not match against ",$source->id,"\n";
    }
    print "\n";
}

=head1 AUTHOR

Inverse inc. <info@inverse.ca>

Minor parts of this file may have been contributed. See CREDITS.

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

