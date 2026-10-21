#!/usr/bin/perl

=head1 NAME

password_of_the_day

=head1 DESCRIPTION

The password_of_the_day pfcron task creates the password of a POTD person
that has none, as left by the deletion of a source whose person still has
devices (#4725)

=cut

use strict;
use warnings;

BEGIN {
    #include test libs
    use lib qw(/usr/local/pf/t);
    #Module for overriding configuration paths
    use setup_test_config;
}

use Test::More tests => 5;
use Test::MockModule;
use pf::pfcron::task::password_of_the_day;

#This test will running last
use Test::NoWarnings;

my (%persons, %passwords, @generated, @emails);
my $task_module = Test::MockModule->new('pf::pfcron::task::password_of_the_day');
$task_module->mock(person_exist => sub { exists $persons{$_[0]} });
$task_module->mock(person_add => sub { $persons{$_[0]} = { pid => $_[0], @_[1 .. $#_] }; 1 });
$task_module->mock(send_email => sub { my ($self, %args) = @_; push @emails, $args{pid} });
my $person_module = Test::MockModule->new('pf::person');
$person_module->mock(person_view => sub { $persons{$_[0]} });
my $password_module = Test::MockModule->new('pf::password');
$password_module->mock(view => sub { $passwords{$_[0]} });
$password_module->mock(generate => sub { push @generated, $_[0]; 'secret' });
my $authentication_module = Test::MockModule->new('pf::authentication');
$authentication_module->mock(getAuthenticationSourcesByType => sub {
    [ map { { id => $_, password_rotation => '1D', password_email_update => 'admin@example.com' } } qw(potd1 user1) ]
});

sub run_task {
    @generated = @emails = ();
    pf::pfcron::task::password_of_the_day->new({ status => 'enabled', id => 'test', interval => 0, type => 'password_of_the_day' })->run();
}

# potd1: the person of a deleted source, kept for its devices, without password
# user1: a local user with the id of a source, without password
%persons = (potd1 => { pid => 'potd1', potd => 'yes' }, user1 => { pid => 'user1', potd => 'no' });
run_task();
is_deeply(\@generated, ['potd1'], 'a POTD person without password gets a new password');
is_deeply(\@emails, ['potd1'], 'and the password is sent');

%passwords = (potd1 => { pid => 'potd1', expiration => '2999-01-01 00:00:00' });
run_task();
is_deeply(\@generated, [], 'a POTD person with a valid password keeps it');
$passwords{potd1}{expiration} = '2000-01-01 00:00:00';
run_task();
is_deeply(\@generated, ['potd1'], 'an expired POTD password is still rotated');

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
