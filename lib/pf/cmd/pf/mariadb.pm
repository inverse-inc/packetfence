package pf::cmd::pf::mariadb;

=head1 NAME

pf::cmd::pf::mariadb -

=head1 SYNOPSIS

  pfcmd mariadb [mariadb options]

Connect to the MariaDB 

=cut

use strict;
use warnings;
use pf::constants::exit_code qw($EXIT_SUCCESS $EXIT_FAILURE);
use pf::constants qw($TRUE $FALSE);
use base qw(pf::cmd);
use pf::config qw(%Config);
my $binary = 'mysql';

sub parseArgs {
    my ($self) = @_;
    $self->{args} = [map { /^(.*)$/;$1 } $self->args];
    return 1;
}

sub _run {
    my ($self) = @_;
    my @args = $self->args;
    my $db = $Config{database};
    { exec($binary, "-u$db->{user}", "-p$db->{pass}", "-h$db->{host}", "-P$db->{port}", "-D$db->{db}", @args) };
    print STDERR "couldn't exec $binary $!";
    return $EXIT_FAILURE; 
}

=head1 AUTHOR

Inverse inc. <info@inverse.ca>

=head1 COPYRIGHT

Copyright (C) 2005-2024 Inverse inc.

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
