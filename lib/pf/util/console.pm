package pf::util::console;

=head1 NAME

pf::util::console -

=cut

=head1 DESCRIPTION

pf::util::console

=cut

use strict;
use warnings;
use IO::Interactive qw(is_interactive);
use Term::ANSIColor;
use pf::constants qw($BLUE_COLOR $TRUE $RED_COLOR $GREEN_COLOR $YELLOW_COLOR);

=head2 colors

colors

=cut

sub colors {
    my $is_interactive = is_interactive();
    return {
        'reset'       => $is_interactive ? color 'reset'       : '',
        'warning'     => $is_interactive ? color $YELLOW_COLOR : '',
        'error'       => $is_interactive ? color $RED_COLOR    : '',
        'success'     => $is_interactive ? color $GREEN_COLOR  : '',
        'status'      => $is_interactive ? color $BLUE_COLOR   : '',
        'interactive' => $is_interactive,
        'disabled'    => $is_interactive ? color $CYAN_COLOR   : '',
    };
}

=head1 AUTHOR

Inverse inc. <info@inverse.ca>

=head1 COPYRIGHT

Copyright (C) 2005-2019 Inverse inc.

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
