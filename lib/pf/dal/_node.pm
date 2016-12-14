package pf::dal::_node;

=head1 NAME

pf::dal::_node -

=cut

=head1 DESCRIPTION

pf::dal::_node -

=cut

use strict;
use warnings;

use base qw(pf::dal);

our @FIELD_NAMES;
our @PRIMARY_KEYS;

BEGIN {
    @FIELD_NAMES = qw(
        autoreg
            device_version
            status
            bypass_vlan
            device_class
            bandwidth_balance
            regdate
            category_id
            device_type
            pid
            machine_account
            dhcp6_enterprise
            dhcp6_fingerprint
            mac
            device_score
            last_arp
            lastskip
            last_dhcp
            user_agent
            dhcp_fingerprint
            computername
            detect_date
            voip
            bypass_role_id
            notes
            time_balance
            sessionid
            dhcp_vendor
            unregdate
        );

    @PRIMARY_KEYS = qw(
        mac
    );
}

use Class::XSAccessor {
    accessors => \@FIELD_NAMES,

    true => [qw(has_primary_key)],

};

sub field_names {
    return [@FIELD_NAMES];
}

sub table { "node" }

our $FIND_SQL = do {
    my $where = join(", ", map { "$_ = ?" } @PRIMARY_KEYS);
    "SELECT * FROM node WHERE $where;";
};

sub _find_one_sql {
    return $FIND_SQL;
}

our $UPDATE_SQL = do {
    my $where = join(", ", map { "$_ = ?" } @PRIMARY_KEYS);
    my $set = join(", ", map { "$_ = ?" } @FIELD_NAMES);
    "UPDATE node SET $set WHERE $where;";
};

sub _update_sql {
    return $UPDATE_SQL;
}

sub _update_data {
    my ($self) = @_;
    my %data;
    @data{@FIELD_NAMES} = @{$self}{@FIELD_NAMES};
    return \%data;
}

sub _update_fields {
    return [@FIELD_NAMES, @PRIMARY_KEYS];
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
