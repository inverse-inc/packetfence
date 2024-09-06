package pf::SwitchSupports;

=head1 NAME

pf::SwitchSupports -

=head1 DESCRIPTION

pf::SwitchSupports

=cut

use strict;
use warnings;
use pf::constants;
use List::MoreUtils qw(uniq);

sub import {
    my ($class, @args) = @_;
    my ($package, $filename, $line) = caller;
    {
        my %parents = map { $_ => 1} ($package->can("supports") ?  $package->supports() : ());
        my @supports;
        no strict qw(refs);
        for my $s (@args) {
            if ($s =~ /^-(.*)$/) {
                {
                    my $n = $1;
                    delete $parents{$n};
                    *{"${package}::supports$n"} = sub {
                        my $proto = $_[0];
                        my $class = ref($proto) || $proto;
                        $proto->logger->debug("Switch type '$class' does not support $n");
                        $FALSE
                    };
                }
                next;
            }
            my $tested = \&tested;

            if ($s =~ /^\?(.*)$/) {
                my $n = $1;
                push @supports, $n;
                *{"${package}::supports${n}Tested"} = $tested;
                next;
            }


            if ($s =~ /^~(.*)$/) {
                $s = $1;
                $tested = \&untested;
            }

            *{"${package}::supports$s"} = \&support;
            *{"${package}::supports${s}Tested"} = $tested;
            push @supports, $s;
        }
        push @supports, keys %parents;
        @supports = uniq @supports;
        @supports = sort @supports;
        *{"${package}::supports"} = sub { @supports };
    }
}

sub support { $TRUE }

sub tested { $TRUE }

sub untested { $FALSE }

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
