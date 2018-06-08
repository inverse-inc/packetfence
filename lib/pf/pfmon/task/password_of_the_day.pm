package pf::pfmon::task::password_of_the_day;

=head1 NAME

pf::pfmon::task::password_of_the_day - class for pfmon task password generation

=cut

=head1 DESCRIPTION

pf::pfmon::task::password_of_the_day

=cut

use strict;
use warnings;
use Moose;
use pf::person;
use pf::password;
use pf::authentication;
use pf::util;
use DateTime;
use DateTime::Format::MySQL;
use pf::log;

extends qw(pf::pfmon::task);

=head2 run

run the password generation task

=cut

sub run {
    my $now = DateTime->now();
    my $logger = get_logger();
    my @sources = pf::authentication::getAuthenticationSourcesByType("Potd");
    my $new_password;
    foreach my $source (@sources) {
        unless (person_exist($source->{user})) {
            $logger->info("Create Person $source->{user}");
            person_add($source->{user});
            $new_password = pf::password::generate($source->{user},{type => 'valid_from', value => $now},undef,'0');
        }
        my $password = pf::password::view($source->{user});
        if(defined($password)){
            my $valid_from = $password->{valid_from};
            $valid_from = DateTime::Format::MySQL->parse_datetime($valid_from);
            if ($now->subtract_datetime_absolute( $valid_from ) > pf::util::normalize_time($source->{password_rotation})) {
                $new_password = pf::password::generate($source->{user},{type => 'valid_from', value => $now},undef,'0');
            }
        }
    }
}

=head1 AUTHOR


Inverse inc. <info@inverse.ca>

=head1 COPYRIGHT

Copyright (C) 2005-2018 Inverse inc.

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

