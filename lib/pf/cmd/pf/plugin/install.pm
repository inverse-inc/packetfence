package pf::cmd::pf::plugin::install;

=head1 NAME

pf::cmd::pf::plugin::install

=head1 SYNOPSIS

 pfcmd plugin install <name|package file>

Installs the package of a plugin with apt-get or dnf: a name (acme installs
packetfence-plugin-acme from the configured repositories) or a package file
(.deb, .rpm). The package applies its tables, then starts and registers its
service.

=cut

use strict;
use warnings;
use pf::ui_plugins::packages;
use base qw(pf::cmd);
use Role::Tiny::With;
with 'pf::cmd::roles::root_only';

sub parseArgs {
    my ($self) = @_;
    my @args = $self->args;
    return 0 if @args != 1;
    $self->{what} = $args[0];
    return 1;
}

sub _run {
    my ($self) = @_;
    my $code = eval { pf::ui_plugins::packages::install($self->{what}) };
    if ($@) {
        print STDERR $@;
        return 1;
    }
    return $code;
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
