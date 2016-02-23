package pf::detect::parser::snort;
=head1 NAME

pf::detect::parser::snort

=cut

=head1 DESCRIPTION

pf::detect::parser::snort

Class to parse syslog from Snort

=cut

use strict;
use warnings;
use Moo;
extends qw(pf::detect::parser);

sub parse {
    my ($self,$line) = @_;
    my $data;
    if ( $line
        =~ /^(.*)\[\d+:(\d+):\d+\]\s+(.+?)\s+\[.+?(\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3})(:\d+){0,1}\s+\-\>\s+(\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3})(:\d+){0,1}/
        )
    {
    
        $data = {
            date  => $1,
            sid   => $2,
            descr => $3,
            srcip => $4,
            dstip => $6,
        };
        return { srcip => $data->{srcip}, date => $data->{date}, dstip => $data->{dstip}, events => { detect => $data->{sid}, suricata_event => $data->{descr} } };
    } elsif ( $line
        =~ /^(.+?)\s+\[\*\*\]\s+\[\d+:(\d+):\d+\]\s+Portscan\s+detected\s+from\s+(\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3})/
        )
    {
        $data = {
            date  => $1,
            srcip => $3,
            descr => "PORTSCAN",
        };
        return { srcip => $data->{srcip}, date => $data->{date}, events => { detect => $data->{descr} } };
    } elsif ( $line
        =~ /^(.+?)\[\*\*\] \[\d+:(\d+):\d+\]\s+\(spp_portscan2\) Portscan detected from (\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3})/
        )
    {
        $data = {
            date  => $1,
            srcip => $3,
            descr => "PORTSCAN",
        };
        return { srcip => $data->{srcip}, date => $data->{date}, events => { detect => $data->{descr} } };
    }
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

