package pf::cmd::roles::root_only;

=head1 NAME

pf::cmd::roles::root_only

=head1 DESCRIPTION

A pf::cmd command that only root may run: bin/pfcmd is setuid root, so the
command is refused unless the real uid of the caller of pfcmd
(pf::cmd::caller_uid) is 0.

The check wraps _run, so it holds however the command is reached: through its
parent command or loaded directly.

A command can let some of its runs through by overriding allowed_without_root
(eg the help of a subcommand container).

=cut

use strict;
use warnings;
use Role::Tiny;
use pf::constants::exit_code qw($EXIT_FAILURE);

around _run => sub {
    my ($orig, $self, @args) = @_;
    if (pf::cmd::caller_uid() != 0 && !$self->allowed_without_root) {
        print STDERR "pfcmd: only root can run this command\n";
        return $EXIT_FAILURE;
    }
    return $self->$orig(@args);
};

=head2 allowed_without_root

True when this run does not need root. Defaults to false.

=cut

sub allowed_without_root { 0 }

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
