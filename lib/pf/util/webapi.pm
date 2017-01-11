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

sub add_mac_to_log_context {
    my ($args) = @_;
    return unless defined $args;
    my $params;
    if (@$args == 1) {
        if (ref($args->[0]) eq 'HASH') {
            $params = $args->[0];
        }
        else {
            return;
        }
    }
    else {
        $params = {@$args};
    }
    if ($params) {
        for my $key (qw(mac Calling-Station-Id User-Name)) {
            if (exists $params->{$key}) {
                my $mac = clean_mac($params->{$key});
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
