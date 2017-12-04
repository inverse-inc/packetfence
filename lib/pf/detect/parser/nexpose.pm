package pf::detect::parser::nexpose;

=head1 NAME

pf::detect::parser::nexpose

=cut

=head1 DESCRIPTION

pf::detect::parser::nexpose

Class to parse syslog from a Insight Nexpose appliance

=cut

use strict;
use warnings;
use Moo;
extends qw(pf::detect::parser);

sub parse {
    my ($self,$line) = @_;

    # Alert line example
    # Nov 13 11:38:09 172.20.120.70 Nexpose: 10.0.0.20 VULNERABILITY: OpenSSL SSL/TLS MITM vulnerability (CVE-2014-0224) (http-openssl-cve-2014-0224)
    if ($line =~ /^(\w+ \d+ \d+:\d+:\d+) ([0-9.]+) \w+: ([0-9.]+) (\w+): (.*)/) {

        my $data = {
            date        => $1,
            serverip    => $2,
            deviceip    => $3,
            alerttype   => $4,
            descr       => $5,
        };
        return { date => $data->{date}, srcip => $data->{serverip}, dstip => $data->{deviceip}, events => { nexpose_event => $data->{descr} } } if $data->{alerttype} eq 'VULNERABILITY' ;
    }
}

=head1 AUTHOR

Inverse inc. <info@inverse.ca>

=head1 COPYRIGHT

Copyright (C) 2005-2017 Inverse inc.

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
