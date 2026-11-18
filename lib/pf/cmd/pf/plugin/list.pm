package pf::cmd::pf::plugin::list;

=head1 NAME

pf::cmd::pf::plugin::list

=head1 SYNOPSIS

 pfcmd plugin list

The plugins installed on top of PacketFence: the version of their package
(descriptor), of their tables in the database, their registration and the
state of their admin UI code (ok, mismatch, missing, none).

=cut

use strict;
use warnings;
use pf::constants::exit_code qw($EXIT_SUCCESS);
use pf::ui_plugins::packages;
use base qw(pf::cmd);
use Role::Tiny::With;
with 'pf::cmd::roles::root_only';

sub _run {
    my ($self) = @_;
    my $plugins = pf::ui_plugins::packages::list();
    my @columns = (['name', 'NAME'], ['version', 'VERSION'], ['schema', 'TABLES'], ['registration', 'REGISTERED'], ['bundle', 'UI CODE']);
    my @rows = map { my $p = $_; [ map { $p->{$_->[0]} // '-' } @columns ] } @$plugins;
    my @widths = map { my $i = $_; my $w = length($columns[$i][1]); for (@rows) { $w = length($_->[$i]) if length($_->[$i]) > $w } $w } 0 .. $#columns;
    my $format = join('  ', map { "%-${_}s" } @widths) . "\n";
    printf($format, map { $_->[1] } @columns);
    printf($format, @$_) for @rows;
    for my $p (grep { $_->{error} } @$plugins) {
        print STDERR "$p->{name}: $p->{error}\n";
    }
    return $EXIT_SUCCESS;
}

=head1 AUTHOR

Inverse inc. <info@inverse.ca>

Minor parts of this file may have been contributed. See CREDITS.

=head1 COPYRIGHT

Copyright (C) 2005-2026 Inverse inc.

=head1 LICENSE

This program is free software; you can redistribute it and::or
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
