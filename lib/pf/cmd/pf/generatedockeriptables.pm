package pf::cmd::pf::generatedockeriptables;

=head1 NAME

pf::cmd::pf::generatedockeriptables

=head1 SYNOPSIS

  pfcmd generatedockeriptables

Generates and apply the docker iptables rules

=cut

use strict;
use warnings;

use base qw(pf::cmd);

sub _run {
    my ($self) = @_;
    return system("/usr/local/pf/containers/docker_iptables.sh");
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
