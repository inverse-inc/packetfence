package pf::util::webapi;

=head1 NAME

pf::util::webapi -

=cut

=head1 DESCRIPTION

pf::util::webapi

=cut

use strict;
use warnings;
use pf::log;
use pf::util;
use List::MoreUtils qw(natatime);

our %MAC_KEYS = (
    'mac' => 1,
    'Calling-Station-Id' => 1,
    'User-Name' => 1,
);

sub add_mac_to_log_context {
    my ($args) = @_;
    pf::log::reset_log_context();
    return unless defined $args;
    my $params;
    if (@$args == 1) {
        my $tmp = $args->[0];
        if (ref($tmp) eq 'HASH') {
            $params = [%$tmp];
        }
        else {
            return;
        }
    }
    else {
        $params = $args;
    }
    if ((@$params % 2) == 0 ) {
        my $it = natatime 2, @$params;
        while (my ($k, $v) = $it->()) {
            last unless defined $k;
            if (exists $MAC_KEYS{$k}) {
                my $mac = clean_mac($v);
                if ($mac) {
                    Log::Log4perl::MDC->put('mac', $mac);
                    last;
                }
            }
        }
    }
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
