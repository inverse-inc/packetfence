#!/usr/bin/perl -w

package pf::pfcmd::customreport;

use lib qw(/usr/local/pf/lib /usr/local/pf/html/pfappserver/lib);
use lib qw(/home/francis/usr/lib/perl/5.14.2 /home/francis/usr/share/perl/5.14.2);
use strict;
use warnings;
use pf::db;

use constant CUSTOMREPORT => 'pfcmd::customreport';

BEGIN {
    use Exporter ();
    our (@ISA, @EXPORT);
    @ISA = qw(Exporter);
    @EXPORT = qw(
                    $customreport_db_prepared
                    customreport_db_prepare
                    customreport_nodereg
               );
}

our $customreport_db_prepared = 0;
our $customreport_statements = {};

sub customreport_db_prepare {
    $customreport_statements->{'nodereg_date_maclocation_sql'} = get_db_handle()->prepare(qq[
  SELECT
    n.pid,
    n.regdate,
    (SELECT
       l.switch_mac
     FROM
       locationlog l
     WHERE
       l.mac = n.mac
     ORDER BY
       l.start_time DESC
     LIMIT
       1) AS switch_mac
  FROM
    node n
  WHERE
    n.status = 'reg' AND n.regdate > DATE_SUB(NOW(), INTERVAL 1 WEEK)
]);

    $customreport_db_prepared = 1;
    return 1;
}

sub customreport_nodereg {
    my @data = db_data(CUSTOMREPORT, $customreport_statements, 'nodereg_date_maclocation_sql');

    my ($pid, $regdate, $switch_mac);
    format STDOUT =
10050001_20130718 | @>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>> | @<<<<<<<<<<<<<<<<<< | @<<<<<<<<<<<<<<<<<
                    $pid, $regdate, $switch_mac
.

    foreach my $row (@data) {
        ($pid, $regdate, $switch_mac) = ($row->{pid}, $row->{regdate}, $row->{switch_mac});
        write();
    }
}

&pf::pfcmd::customreport::customreport_nodereg();

1;
