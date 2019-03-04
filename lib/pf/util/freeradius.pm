package pf::util::freeradius;

=head1 NAME

pf::util::freeradius - FreeRADIUS rlm_perl related utilities

=cut

=head1 DESCRIPTION

Small thread-safe utilities for our FreeRADIUS rlm_perl modules.

=cut

use strict;
use warnings;

BEGIN {
    use Exporter ();
    our ( @ISA, @EXPORT_OK );
    @ISA = qw(Exporter);
    @EXPORT_OK = qw(clean_mac sanitize_parameter);
}

=head1 SUBROUTINES

=over

=item clean_mac

Clean a MAC address accepting xx-xx-xx-xx-xx-xx, xx:xx:xx:xx:xx:xx, xxxx-xxxx-xxxx and xxxx.xxxx.xxxx.

Returns a string with MAC in format: xx:xx:xx:xx:xx:xx

=cut

sub clean_mac {
    my ($mac) = @_;
    return (0) if ( !$mac );
    # trim garbage
    $mac =~ s/[\s\-\.:]//g;
    # lowercase
    $mac = lc($mac);
    # inject :
    $mac =~ s/([a-f0-9]{2})(?!$)/$1:/g if ( $mac =~ /^[a-f0-9]{12}$/i );
    return ($mac);
}

=item sanitize_parameter

URL encode illegal characters from WS_USER/WS_PASS used in SOAP calls.

Ref: http://tools.ietf.org/html/rfc1738#section-3.1

=cut

sub sanitize_parameter {
    my ($parameter) = @_;

    my %ascii_hex_value = (
        ':' => '%3A',
        '@' => '%40',
        '/' => '%2F',
    );

    while (my ($find, $replace) = each %ascii_hex_value) {
        eval { $parameter =~ s{$find}{$replace}g; };
    }

    return $parameter;
}

=back

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
