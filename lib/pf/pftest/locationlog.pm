package pf::pftest::locationlog;
=head1 NAME

pf::pftest::locationlog

=head1 SYNOPSIS

pftest locationlog

=head1 DESCRIPTION

pf::pftest::locationlog

=cut

use strict;

use warnings;
use base qw(pf::cmd);
use pf::constants::exit_code qw($EXIT_SUCCESS $EXIT_FAILURE);
use pf::constants qw($ZERO_DATE);
sub parseArgs { $_[0]->args == 0 }

sub _run {
    my ($self) = @_;
    require pf::db;
    my $dbh = pf::db::db_connect();
    my $sth = $dbh->prepare(qq[ select mac,count(mac) as entries from locationlog where end_time = '$ZERO_DATE' group by mac having count(mac) > 1; ]);
    die unless $sth;
    $sth->execute();
    my $rv  = $sth->rows;
    my $format_header = "%-17s %10s\n";
    print "Found $rv nodes with multiple opened locationlog entries\n";
    return $EXIT_SUCCESS unless $rv > 0;
    print sprintf($format_header,"mac", "count");
    while(my $row = $sth->fetchrow_hashref) {
        print sprintf( "%-17s %10d\n",$row->{mac}, $row->{entries});
    }
    return 0;
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

