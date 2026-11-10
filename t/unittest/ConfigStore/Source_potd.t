#!/usr/bin/perl

=head1 NAME

Source_potd

=head1 DESCRIPTION

Deleting a Password Of The Day source removes the person and the password
created by pfcron for it, and nothing else

=cut

use strict;
use warnings;

BEGIN {
    #include test libs
    use lib qw(/usr/local/pf/t);
    #Module for overriding configuration paths
    use setup_test_config;
}

use Test::More tests => 6;

#This test will running last
use Test::NoWarnings;
use pf::ConfigStore::Source;
use pf::person;
use pf::dal::password;

my (%persons, @removed_passwords, @deleted_persons);
{
    no warnings qw(redefine once);
    *pf::person::person_view = sub { my ($pid) = @_; return exists $persons{$pid} ? { pid => $pid, %{$persons{$pid}} } : 0 };
    *pf::person::person_delete = sub { push @deleted_persons, $_[0]; return 1 };
    *pf::dal::password::remove_by_id = sub { push @removed_passwords, $_[1]{pid}; return 1 };
}

sub cleanup {
    my ($id) = @_;
    (@removed_passwords, @deleted_persons) = ();
    pf::ConfigStore::Source->new->cleanupPotd($id);
    return ([@removed_passwords], [@deleted_persons]);
}

%persons = (potd1 => { potd => 'yes' }, admin => { potd => 'no' }, localuser => { potd => undef });

my ($passwords, $deleted) = cleanup('potd1');
is_deeply($passwords, ['potd1'], 'the password of the person created by pfcron is removed');
is_deeply($deleted, ['potd1'], 'and the person is deleted');

($passwords, $deleted) = cleanup('admin');
is_deeply([ @$passwords, @$deleted ], [], 'an existing person that is not a POTD person (admin) is untouched');

($passwords, $deleted) = cleanup('localuser');
is_deeply([ @$passwords, @$deleted ], [], 'a local user without potd is untouched');

($passwords, $deleted) = cleanup('neverran');
is_deeply([ @$passwords, @$deleted ], [], 'nothing is done when pfcron never created the person');


=head1 AUTHOR

Inverse inc. <info@inverse.ca>

=head1 COPYRIGHT

Copyright (C) 2005-2026 Inverse inc.

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

1;
