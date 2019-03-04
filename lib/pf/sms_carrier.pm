package pf::sms_carrier;

=head1 NAME

pf::sms_carrier add documentation

=cut

=head1 DESCRIPTION

pf::sms_carrier

=cut

use strict;
use warnings;
use pf::db;
use pf::log;
use pf::error qw(is_error);
use pf::dal::sms_carrier;

BEGIN {
    use Exporter ();
    our (@ISA, @EXPORT);
    @ISA    = qw(Exporter);
    @EXPORT = qw(sms_carrier_view_all sms_carrier_view);
}

=head1 SUBROUTINES

=head2 sms_carrier_view_all

=cut

sub sms_carrier_view_all {
    my $source = shift;
    # Check if a SMS authentication source is defined; if so, use the carriers list
    # from this source
    my %search = (
            -columns => [qw(id name)]
    );
    if ($source) {
        $search{-where} = {
            id => $source->{'sms_carriers'}
        };
    }
    my ($status, $iter) = pf::dal::sms_carrier->search(%search);
    return [] if is_error($status);
    my $val = $iter->all(undef);

    return $val;
}

=head2 sms_carrier_view

=cut

sub sms_carrier_view {
    my $id = shift;
    my ($status, $item) = pf::dal::sms_carrier->find({id=>$id});
    if (is_error($status)) {
        return (0);
    }
    return ($item->to_hash());
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

