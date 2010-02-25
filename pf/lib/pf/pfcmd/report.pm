=head1 NAME

pf::pfcmd::report - all about reports

=cut

=head1 DESCRIPTION

TBD

=head1 CONFIGURATION AND ENVIRONMENT

Read the F<pf.conf> configuration file.

=cut

use strict;
use warnings;
use Log::Log4perl;

use pf::config;
use pf::db;
use pf::util;

use vars
    qw/$report_active_all_sql $report_inactive_all_sql $report_unregistered_active_sql $report_unregistered_all_sql
    $report_registered_active_sql $report_registered_all_sql $report_os_active_sql $report_os_all_sql $report_osclass_all_sql
    $report_osclass_active_sql $report_unknownprints_all_sql $report_unknownprints_active_sql $report_openviolations_all_sql
    $report_openviolations_active_sql $report_statics_all_sql $report_statics_active_sql $is_report_db_prepared @ISA @EXPORT/;

$is_report_db_prepared = 0;

#report_db_prepare($dbh);

=head1 SUBROUTINES

TODO: list incomplete

=over

=cut
sub report_db_prepare {
    my ($dbh) = @_;
    db_connect($dbh);
    my $logger = Log::Log4perl::get_logger('pf::pfcmd::report');
    $report_inactive_all_sql
        = $dbh->prepare(
        qq [ select n.mac,pid,detect_date,regdate,lastskip,status,user_agent,computername,notes,last_arp,last_dhcp,o.description as os from node n LEFT JOIN dhcp_fingerprint d ON n.dhcp_fingerprint=d.fingerprint LEFT JOIN os_type o ON o.os_id=d.os_id where n.mac not in (select i.mac from iplog i where i.end_time=0 or i.end_time > now()) ]
        );
    $report_active_all_sql
        = $dbh->prepare(
        qq [ select n.mac,ip,start_time,pid,detect_date,regdate,lastskip,status,user_agent,computername,notes,last_arp,last_dhcp,o.description as os from (node n,iplog i) LEFT JOIN dhcp_fingerprint d ON n.dhcp_fingerprint=d.fingerprint LEFT JOIN os_type o ON o.os_id=d.os_id where i.mac=n.mac and (i.end_time=0 or i.end_time > now()) ]
        );
    $report_unregistered_all_sql
        = $dbh->prepare(
        qq [ select n.mac,pid,detect_date,regdate,lastskip,status,user_agent,computername,notes,last_arp,last_dhcp,o.description as os FROM node n LEFT JOIN dhcp_fingerprint d ON n.dhcp_fingerprint=d.fingerprint LEFT JOIN os_type o ON o.os_id=d.os_id where n.status='unreg' ]
        );
    $report_unregistered_active_sql
        = $dbh->prepare(
        qq [ select n.mac,pid,detect_date,regdate,lastskip,status,user_agent,computername,notes,last_arp,last_dhcp,o.description as os FROM (node n,iplog i) LEFT JOIN dhcp_fingerprint d ON n.dhcp_fingerprint=d.fingerprint LEFT JOIN os_type o ON o.os_id=d.os_id where n.status='unreg' and i.mac=n.mac and (i.end_time=0 or i.end_time > now()) ]
        );
    $report_registered_all_sql
        = $dbh->prepare(
        qq [ select n.mac,pid,detect_date,regdate,lastskip,status,user_agent,computername,notes,last_arp,last_dhcp,o.description as os FROM node n LEFT JOIN dhcp_fingerprint d ON n.dhcp_fingerprint=d.fingerprint LEFT JOIN os_type o ON o.os_id=d.os_id where n.status='reg' ]
        );
    $report_registered_active_sql
        = $dbh->prepare(
        qq [ select n.mac,pid,detect_date,regdate,lastskip,status,user_agent,computername,notes,last_arp,last_dhcp,o.description as os FROM (node n,iplog i) LEFT JOIN dhcp_fingerprint d ON n.dhcp_fingerprint=d.fingerprint LEFT JOIN os_type o ON o.os_id=d.os_id where n.status='reg' and i.mac=n.mac and (i.end_time=0 or i.end_time > now()) ]
        );
    $report_os_active_sql
        = $dbh->prepare(
        qq [ select o.description,n.dhcp_fingerprint,count(*) as count,ROUND(COUNT(*)/(SELECT COUNT(*) FROM node)*100,1) as percent FROM (node n,iplog i) LEFT JOIN dhcp_fingerprint d ON n.dhcp_fingerprint=d.fingerprint LEFT JOIN os_type o ON o.os_id=d.os_id where n.mac=i.mac and (i.end_time=0 or i.end_time > now()) group by o.description order by percent desc ]
        );
    $report_os_all_sql
        = $dbh->prepare(
        qq [select o.description,n.dhcp_fingerprint,count(*) as count,ROUND(COUNT(*)/(SELECT COUNT(*) FROM node)*100,1) as percent FROM node n LEFT JOIN dhcp_fingerprint d ON n.dhcp_fingerprint=d.fingerprint LEFT JOIN os_type o ON o.os_id=d.os_id group by o.description order by percent desc ]
        );
    $report_osclass_all_sql
        = $dbh->prepare(
        qq [ select c.description,count(*) as count,ROUND(COUNT(*)/(SELECT COUNT(*) FROM node)*100,1) as percent from node n LEFT JOIN dhcp_fingerprint d ON n.dhcp_fingerprint=d.fingerprint left join os_mapping m on m.os_type=d.os_id left join os_class c on m.os_class=c.class_id group by c.description order by percent desc ]
        );
    $report_osclass_active_sql
        = $dbh->prepare(
        qq [ select c.description,count(*) as count,ROUND(COUNT(*)/(SELECT COUNT(*) FROM node,iplog where node.mac=iplog.mac and (iplog.end_time=0 or iplog.end_time > now()))*100,1) as percent from (node n,iplog i) LEFT JOIN dhcp_fingerprint d ON n.dhcp_fingerprint=d.fingerprint left join os_mapping m on m.os_type=d.os_id left join os_class c on m.os_class=c.class_id where n.mac=i.mac and (i.end_time=0 or i.end_time > now()) group by c.description order by percent desc ]
        );
    $report_unknownprints_all_sql
        = $dbh->prepare(
        qq [SELECT mac,dhcp_fingerprint,computername,user_agent FROM node WHERE dhcp_fingerprint NOT IN (SELECT fingerprint FROM dhcp_fingerprint) and dhcp_fingerprint!=0 ORDER BY dhcp_fingerprint, mac ]
        );
    $report_unknownprints_active_sql
        = $dbh->prepare(
        qq [SELECT node.mac,dhcp_fingerprint,computername,user_agent FROM node,iplog WHERE dhcp_fingerprint NOT IN (SELECT fingerprint FROM dhcp_fingerprint) and dhcp_fingerprint!=0 and node.mac=iplog.mac and (iplog.end_time=0 or iplog.end_time > now()) ORDER BY dhcp_fingerprint, mac]
        );
    $report_statics_all_sql
        = $dbh->prepare(
        qq [SELECT * FROM node WHERE dhcp_fingerprint="" OR dhcp_fingerprint IS NULL]
        );
    $report_statics_active_sql
        = $dbh->prepare(
        qq [SELECT * FROM node,iplog WHERE (dhcp_fingerprint="" OR dhcp_fingerprint IS NULL) AND node.mac=iplog.mac and (iplog.end_time=0 or iplog.end_time > now()) ]
        );
    $report_openviolations_all_sql
        = $dbh->prepare(
        qq [SELECT n.pid as owner, n.mac as mac, v.status as status, v.start_date as start_date, c.description as violation from violation v LEFT JOIN node n ON v.mac=n.mac LEFT JOIN class c on c.vid=v.vid WHERE v.status="open" order by n.pid ]
        );
    $report_openviolations_active_sql
        = $dbh->prepare(
        qq [SELECT n.pid as owner, n.mac as mac, v.status as status, v.start_date as start_date, c.description as violation from (violation v, iplog i) LEFT JOIN node n ON v.mac=n.mac LEFT JOIN class c on c.vid=v.vid WHERE v.status="open" and n.mac=i.mac and (i.end_time=0 or i.end_time > now()) order by n.pid ]
        );
    $is_report_db_prepared = 1;
    return 1;
}

sub report_os_all {
    report_db_prepare($dbh) if ( !$is_report_db_prepared );
    my @data    = db_data($report_os_all_sql);
    my $statics = scalar( db_data($report_statics_all_sql) );
    my $total   = 0;
    my @return_data;

    foreach my $record (@data) {
        $total += $record->{'count'};
    }
    foreach my $record (@data) {
        if ( !$record->{'description'} ) { #this includes static and unknown prints
            $record->{'description'} = 'Unknown DHCP Fingerprint';
            if ( $statics > 0 ) {
                $record->{'count'} -= $statics;
                $record->{'percent'} = sprintf("%.1f", ( $record->{'count'} / $total ) * 100 );

                my $static_percent = sprintf( "%.1f", ( $statics / $total ) * 100 );
                push @return_data,
                    {
                    description => "*Probable Static IP(s)",
                    percent     => $static_percent,
                    count       => $statics
                    };
                
            }
        }
        if ( $record->{'count'} > 0 ) {
            push @return_data, $record;
        }
    }

    push @return_data, { description => "Total", percent => "100", count => $total };
    return (@return_data);
}

sub report_os_active {
    report_db_prepare($dbh) if ( !$is_report_db_prepared );
    my @data    = db_data($report_os_active_sql);
    my $statics = scalar( db_data($report_statics_active_sql) );
    my $total   = 0;
    my @return_data;

    foreach my $record (@data) {
        $total += $record->{'count'};
    }

    foreach my $record (@data) {
        if ( !$record->{'description'} ) { #this includes static and unknown prints
            $record->{'description'} = 'Unknown DHCP Fingerprint';
            if ( $statics > 0 ) {
                $record->{'count'} -= $statics;
                $record->{'percent'} = sprintf("%.1f", ( $record->{'count'} / $total ) * 100 );

                my $static_percent = sprintf( "%.1f", ( $statics / $total ) * 100 );
                push @return_data,
                    {
                    description => "*Probable Static IP(s)",
                    percent     => $static_percent,
                    count       => $statics
                    };

            }
        }
        if ( $record->{'count'} > 0 ) {
            push @return_data, $record;
        }
    }

    push @return_data, { description => "Total", percent => "100", count => $total };
    return (@return_data);
}

sub report_osclass_all {
    report_db_prepare($dbh) if ( !$is_report_db_prepared );
    my @data    = db_data($report_osclass_all_sql);
    my $statics = scalar( db_data($report_statics_all_sql) );
    my $total   = 0;
    my @return_data;

    foreach my $record (@data) {
        $total += $record->{'count'};
    }

    foreach my $record (@data) {
        if ( !$record->{'description'} ) { #this includes static and unknown prints
            $record->{'description'} = 'Unknown DHCP Fingerprint';
            if ( $statics > 0 ) {
                $record->{'count'} -= $statics;
                $record->{'percent'} = sprintf("%.1f", ( $record->{'count'} / $total ) * 100 );

                my $static_percent = sprintf( "%.1f", ( $statics / $total ) * 100 );
                push @return_data,
                    {
                    description => "*Probable Static IP(s)",
                    percent     => $static_percent,
                    count       => $statics
                    };

            }
        }
        if ( $record->{'count'} > 0 ) {
            push @return_data, $record;
        }
    }

    push @return_data, { description => "Total", percent => "100", count => $total };
    return (@return_data);
}

sub report_osclass_active {
    report_db_prepare($dbh) if ( !$is_report_db_prepared );
    my @data    = db_data($report_osclass_active_sql);
    my $statics = scalar( db_data($report_statics_active_sql) );
    my $total   = 0;
    my @return_data;

    foreach my $record (@data) {
        $total += $record->{'count'};
    }

    foreach my $record (@data) {
        if ( !$record->{'description'} ) { #this includes static and unknown prints
            $record->{'description'} = 'Unknown DHCP Fingerprint';
            if ( $statics > 0 ) {
                $record->{'count'} -= $statics;
                $record->{'percent'} = sprintf("%.1f", ( $record->{'count'} / $total ) * 100 );

                my $static_percent = sprintf( "%.1f", ( $statics / $total ) * 100 );
                push @return_data,
                    {
                    description => "*Probable Static IP(s)",
                    percent     => $static_percent,
                    count       => $statics
                    };

            }
        }
        if ( $record->{'count'} > 0 ) {
            push @return_data, $record;
        }
    }
}

sub report_active_all {
    report_db_prepare($dbh) if ( !$is_report_db_prepared );
    return db_data($report_active_all_sql);
}

sub report_inactive_all {
    report_db_prepare($dbh) if ( !$is_report_db_prepared );
    return db_data($report_inactive_all_sql);
}

sub report_unregistered_active {
    report_db_prepare($dbh) if ( !$is_report_db_prepared );
    return db_data($report_unregistered_active_sql);
}

sub report_unregistered_all {
    report_db_prepare($dbh) if ( !$is_report_db_prepared );
    return db_data($report_unregistered_all_sql);
}

sub report_active_reg {
    report_db_prepare($dbh) if ( !$is_report_db_prepared );
    return db_data($report_registered_active_sql);
}

sub report_registered_all {
    report_db_prepare($dbh) if ( !$is_report_db_prepared );
    return db_data($report_registered_all_sql);
}

sub report_registered_active {
    report_db_prepare($dbh) if ( !$is_report_db_prepared );
    return db_data($report_registered_active_sql);
}

sub report_openviolations_all {
    report_db_prepare($dbh) if ( !$is_report_db_prepared );
    return db_data($report_openviolations_all_sql);
}

sub report_openviolations_active {
    report_db_prepare($dbh) if ( !$is_report_db_prepared );
    return db_data($report_openviolations_active_sql);
}

sub report_statics_all {
    report_db_prepare($dbh) if ( !$is_report_db_prepared );
    return _translate_connection_type(db_data($report_statics_all_sql));
}

sub report_statics_active {
    report_db_prepare($dbh) if ( !$is_report_db_prepared );
    return _translate_connection_type(db_data($report_statics_active_sql));
}

sub report_unknownprints_all {
    report_db_prepare($dbh) if ( !$is_report_db_prepared );
    my @data = db_data($report_unknownprints_all_sql);
    foreach my $datum (@data) {
        $datum->{'vendor'} = oui_to_vendor( $datum->{'mac'} );
    }
    return (@data);
}

sub report_unknownprints_active {
    report_db_prepare($dbh) if ( !$is_report_db_prepared );
    my @data = db_data($report_unknownprints_active_sql);
    foreach my $datum (@data) {
        $datum->{'vendor'} = oui_to_vendor( $datum->{'mac'} );
    }
    return (@data);
}

=item * _translate_connection_type

Translates connection_type database string into a human-understandable string

=cut
# TODO we can probably be more efficient than that by passing references and stuff
sub _translate_connection_type {
    my (@data) = @_;

    # change connection_type into its meaningful to humans counterpart
    foreach my $datum (@data) {

        my $conn_type = str_to_connection_type($datum->{'connection_type'});
        if (defined($conn_type)) {                                                                                                  $datum->{'connection_type'} = $connection_type_explained{$conn_type};                                               } else {                                                                                                                    $datum->{'connection_type'} = "UNKNOWN";
        }
    }
    return (@data);
}

=head1 AUTHOR

David LaPorte <david@davidlaporte.org>

Kevin Amorin <kev@amorin.org>

Olivier Bilodeau <obilodeau@inverse.ca>

=head1 COPYRIGHT

Copyright (C) 2005 David LaPorte

Copyright (C) 2005 Kevin Amorin

Copyright (C) 2010 Olivier Bilodeau

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
