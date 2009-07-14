package pf::useragent;

=head1 NAME

pf::useragent - module for useragent management.

=cut

=head1 DESCRIPTION

pf::useragent handles the queries against useragent information in the database

=cut

use strict;
use warnings;
use Log::Log4perl;

our (
    $useragent_match_sql, $useragent_view_all_sql,
    $useragent_db_prepared
);

BEGIN {
    use Exporter ();
    our ( @ISA, @EXPORT );
    @ISA = qw(Exporter);
    @EXPORT
        = qw(useragent_db_prepare useragent_match useragent_view_all);
}

use pf::config;
use pf::db;
use pf::trigger qw(trigger_in_range);

$useragent_db_prepared = 0;

sub useragent_db_prepare {
    my ($dbh) = @_;
    db_connect($dbh);
    my $logger = Log::Log4perl::get_logger('pf::useragent');
    $logger->debug("Preparing pf::useragent database queries");
    $useragent_match_sql
        = $dbh->prepare(
        qq [ SELECT ut.match_expression,ut.useragent_id,ut.description as useragent,c.class_id,c.description as class FROM useragent_type ut LEFT JOIN useragent_mapping m ON m.useragent_type=ut.useragent_id LEFT JOIN useragent_class c ON  m.useragent_class=c.class_id WHERE ? regexp ut.match_expression GROUP BY c.class_id ORDER BY class_id ]
        );
    $useragent_view_all_sql
        = $dbh->prepare(
        qq [ SELECT ut.match_expression,ut.description as useragent,c.description as class FROM useragent_type ut LEFT JOIN useragent_mapping m ON m.useragent_type=ut.useragent_id LEFT JOIN useragent_class c ON  m.useragent_class=c.class_id ORDER BY class_id ]
        );

    $useragent_db_prepared = 1;
}

sub useragent_match {
    my ($useragent) = @_;
    useragent_db_prepare($dbh) if ( !$useragent_db_prepared );
    return db_data( $useragent_match_sql, $useragent );
}

sub useragent_view_all {
    useragent_db_prepare($dbh) if ( !$useragent_db_prepared );
    return db_data($useragent_view_all_sql);
}

=head1 AUTHOR

Olivier Bilodeau <obilodeau@inverse.ca>

=head1 COPYRIGHT

Copyright (C) 2009 Inverse inc.

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
