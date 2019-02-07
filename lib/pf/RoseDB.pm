package pf::RoseDB;

=head1 NAME

pf::RoseDB add documentation

=cut

=head1 DESCRIPTION

pf::RoseDB

=cut

use strict;
use warnings;

use Rose::DB;
use pf::db;
use List::MoreUtils qw(any);
our @ISA = qw(Rose::DB);

__PACKAGE__->use_private_registry;

# Register your lone data source using the default type and domain
our $DB_Config = $pf::Config{'database'};

__PACKAGE__->register_db(
    domain   => pf::RoseDB->default_domain,
    type     => pf::RoseDB->default_type,
    driver   => 'mysql',
    connect_options => {
        RaiseError => 0,
        PrintError => 0,
        mysql_auto_reconnect => 0,
    },
);

sub dbh {
    my $dbh;
    eval {
        $dbh = db_connect(); 
    };
    return $dbh;
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

