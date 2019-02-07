package pfconfig::namespaces::resource::switches_ranges;

=head1 NAME

pfconfig::namespaces::resource::switches_ranges

=cut

=head1 DESCRIPTION

pfconfig::namespaces::resource::switches_ranges

This module creates the configuration hash of all the switches ranges (ex : 192.168.1.0/24)

=cut

use strict;
use warnings;

use base 'pfconfig::namespaces::resource';

use NetAddr::IP;

sub init {
    my ($self) = @_;
    # we depend on the switch configuration object (russian doll style)
    $self->{switches} = $self->{cache}->get_cache('config::Switch');
}

sub build {
    my ($self) = @_;
    my @ranges;
    foreach my $switch ( keys %{$self->{switches}} ) {
        my $network = NetAddr::IP->new($switch);
        next if (!defined($network) || ($network->num eq 1) || $switch eq "default");
        push @ranges,[$network,$switch];
    }
    my @ordered_ranges = sort { $b->[0]->masklen <=> $a->[0]->masklen } @ranges ;
    return \@ordered_ranges;
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

# vim: set shiftwidth=4:
# vim: set expandtab:
# vim: set backspace=indent,eol,start:

