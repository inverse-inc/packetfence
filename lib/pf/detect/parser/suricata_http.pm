package pf::detect::parser::suricata_http;

=head1 NAME

pf::detect::parser::suricata_http

=cut

=head1 DESCRIPTION

pfdetect parser class for Suricata HTTP MD5 checksum mode

=cut

use strict;
use warnings;

use JSON;
use Moo;

use pf::api::queue;

extends qw(pf::detect::parser);

sub parse {
    my ( $self, $line ) = @_;

    # Received line should be JSON encoded
    $line =~ s/^.*?{/{/s;
    my $data = decode_json($line);

    my $apiclient = pf::api::queue->new;
    $apiclient->notify('metascan_process', $data);

    return 0;
}

=head1 AUTHOR

Inverse inc. <info@inverse.ca>

=head1 COPYRIGHT

Copyright (C) 2005-2016 Inverse inc.

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
