package pfconfig::timeme;

=head1 NAME

pfconfig::timeme

=cut

=head1 DESCRIPTION

pfconfig::timeme

Defines the timeme function that can be use to add timing
to a function passed as an argument

=cut

use strict;
use warnings;
use pfconfig::log;

=head2 VERBOSE

Defines if the module should be verbose
Set to 1 to activate

=cut

our $VERBOSE = 0;

=head2 timeme

Used to time a method ($fct)

=cut

sub timeme {
    my ( $desc, $fct, $verbose ) = @_;
    if ( $VERBOSE || $verbose ) {
        my $logger = pfconfig::log::get_logger;
        my $start  = Time::HiRes::gettimeofday();
        $fct->();
        my $end = Time::HiRes::gettimeofday();
        my $time = sprintf( "%.5f\n", $end - $start );
        $logger->trace("$desc took : $time");
        print "$desc took : $time\n";
        return $end - $start;
    }
    else {
        $fct->();
    }
}

=head2 time_me_x

Used to time a method for x amount of times

=cut

sub time_me_x {
    my ( $desc, $times, $fct, $verbose ) = @_;
    my @range = ( 1 .. $times );
    timeme(
        "$desc $times times",
        sub {
            foreach my $i (@range) {
                $fct->();
            }
        },
        $verbose
    );
}

=back

=head1 AUTHOR

Inverse inc. <info@inverse.ca>

=head1 COPYRIGHT

Copyright (C) 2005-2015 Inverse inc.

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

# vim: set shiftwidth=4:
# vim: set expandtab:
# vim: set backspace=indent,eol,start:

