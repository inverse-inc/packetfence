package pf::AtFork;

=head1 NAME

pf::AtFork -

=head1 DESCRIPTION

pf::AtFork

=cut

use strict;
use warnings;
our @child_callbacks;

sub add_to_child {
    my ($class, @cbs) = @_;
    push @child_callbacks, @cbs;
}


sub run_child_child_callbacks {
    for my $cb (@child_callbacks) {
        $cb->();
    }
}

sub pf_fork {
    my $pid = fork();
    if (defined $pid && $pid == 0) {
         run_child_child_callbacks();   
    }

    return $pid;
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
