package pf::util::wmi;

=head1 NAME

pf::util::wmi - utilities for wmi

=cut

=head1 DESCRIPTION

pf::util::wmi

=cut

use strict;
use warnings;

=head2 parse_wmi_response

=cut

sub parse_wmi_response {
    my ($response, $delimiter) = @_;
    $delimiter //= '|';
    $response =~ s/\r\n/\n/g;
    my ($class_header, $row_header, @rows) = split /\n/, $response;
    my $regex = qr/\Q$delimiter\E/;
    my @fields = split $regex, $row_header;
    my @results;
    foreach my $row (@rows) {
        my %data;
        @data{@fields} = split /\Q$delimiter\E/, $row;
        push @results, \%data;
    }
    return \@results;
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
