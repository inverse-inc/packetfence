package pf::pftest::iplogs_not_closed;
=head1 NAME

pf::pftest::iplogs_not_closed

=head1 SYNOPSIS

pftest iplogs_not_closed

=head1 DESCRIPTION

pf::pftest::iplogs_not_closed

=cut

use strict;

use warnings;
use base qw(pf::cmd);
sub parseArgs { $_[0]->args == 0 }

sub _run {
    my ($self) = @_;
    require pf::db;
    my $dbh = pf::db::db_connect();
    my $sth = $dbh->prepare(q[ select mac,count(mac) as entries from iplog where end_time ='0000-00-00 00:00:00' or end_time > NOW() group by mac having count(mac) > 1; ]);
    die unless $sth;
    my $rv  = $sth->rows;
    print "Found $rv nodes with multiple opened iplog\n";
    while(my $row = $sth->fetchrow_hashref) {
        print $row->{mac}, " ", $row->{entries},"\n";
    }
    print "\n";
}
 
=head1 AUTHOR

Inverse inc. <info@inverse.ca>

=head1 COPYRIGHT

Copyright (C) 2005-2015 Inverse inc.

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

