package pf::trigger;

=head1 NAME

pf::trigger - module to manage the triggers related to the violations or
the Nessus scans (if enabled).

=cut

=head1 DESCRIPTION

pf::trigger contains the functions necessary to manage the different 
triggers related to the violations or the Nessus scans.

=head1 CONFIGURATION AND ENVIRONMENT

Read the F<pf.conf> configuration file.

=cut

use strict;
use warnings;
use Log::Log4perl;

our (
    $trigger_desc_sql,       $trigger_view_vid_sql,
    $trigger_view_sql,       $trigger_view_enable_sql,
    $trigger_view_all_sql,   $trigger_exist_sql,
    $trigger_view_type_sql,  $trigger_add_sql,
    $trigger_delete_vid_sql, $trigger_delete_all_sql,
    $trigger_view_tid_sql,   $trigger_db_prepared
);

BEGIN {
    use Exporter ();
    our ( @ISA, @EXPORT );
    @ISA = qw(Exporter);
    @EXPORT
        = qw(trigger_db_prepare trigger_view trigger_view_enable trigger_view_all trigger_delete_all
        trigger_in_range trigger_add trigger_view_type trigger_view_tid trigger_scan);
}

use pf::config;
use pf::db;
use pf::util;
use pf::violation qw(violation_trigger violation_add);
use pf::iplog qw(ip2mac);

$trigger_db_prepared = 0;

#trigger_db_prepare($dbh) if (!$thread);

sub trigger_db_prepare {
    my ($dbh) = @_;
    db_connect($dbh);
    my $logger = Log::Log4perl::get_logger('pf::trigger');
    $logger->debug("Preparing pf::trigger database queries");
    $trigger_desc_sql = $dbh->prepare(qq [ desc `trigger` ]);
    $trigger_view_sql
        = $dbh->prepare(
        qq[ select tid_start,tid_end,class.vid,type,description from `trigger`,class where class.vid=`trigger`.vid and tid_start<=? and tid_end>=? and type=?]
        );
    $trigger_view_enable_sql
        = $dbh->prepare(
        qq[ select tid_start,tid_end,class.vid,type from `trigger`,class where class.vid=`trigger`.vid and tid_start<=? and tid_end>=? and type=? and disable="N"]
        );
    $trigger_view_vid_sql
        = $dbh->prepare(
        qq[ select tid_start,tid_end,class.vid,description from `trigger`,class where class.vid=`trigger`.vid and class.vid=?]
        );
    $trigger_view_tid_sql
        = $dbh->prepare(
        qq[ select tid_start,tid_end,class.vid,type,description from `trigger`,class where class.vid=`trigger`.vid and tid_start<=? and tid_end>=? ]
        );
    $trigger_view_all_sql
        = $dbh->prepare(
        qq[ select tid_start,tid_end,class.vid,type,description from `trigger`,class where class.vid=`trigger`.vid ]
        );
    $trigger_view_type_sql
        = $dbh->prepare(
        qq[ select tid_start,tid_end,class.vid,type,description from `trigger`,class where class.vid=`trigger`.vid and type=?]
        );
    $trigger_exist_sql
        = $dbh->prepare(
        qq [ select vid,tid_start,tid_end,type from `trigger` where vid=? and tid_start<=? and tid_end>=? and type=?]
        );
    $trigger_add_sql
        = $dbh->prepare(
        qq [ insert into `trigger`(vid,tid_start,tid_end,type) values(?,?,?,?) ]
        );
    $trigger_delete_vid_sql
        = $dbh->prepare(qq [ delete from `trigger` where vid=? ]);
    $trigger_delete_all_sql = $dbh->prepare(qq [ delete from `trigger` ]);
    $trigger_db_prepared    = 1;
    return 1;
}

sub trigger_desc {
    trigger_db_prepare($dbh) if ( !$trigger_db_prepared );
    return db_data($trigger_desc_sql);
}

sub trigger_view {
    my ( $tid, %type ) = @_;
    trigger_db_prepare($dbh) if ( !$trigger_db_prepared );
    return db_data( $trigger_view_sql, $tid, $tid, $type{type} );
}

sub trigger_view_enable {
    my ( $tid, $type ) = @_;
    trigger_db_prepare($dbh) if ( !$trigger_db_prepared );
    return db_data( $trigger_view_enable_sql, $tid, $tid, $type );
}

sub trigger_view_vid {
    my ($vid) = @_;
    trigger_db_prepare($dbh) if ( !$trigger_db_prepared );
    return db_data( $trigger_view_vid_sql, $vid );
}

sub trigger_view_tid {
    my ($tid) = @_;
    trigger_db_prepare($dbh) if ( !$trigger_db_prepared );
    return db_data( $trigger_view_tid_sql, $tid, $tid );
}

sub trigger_view_all {
    trigger_db_prepare($dbh) if ( !$trigger_db_prepared );
    return db_data($trigger_view_all_sql);
}

sub trigger_view_type {
    my ($type) = @_;
    trigger_db_prepare($dbh) if ( !$trigger_db_prepared );
    return db_data( $trigger_view_type_sql, $type );
}

sub trigger_delete_vid {
    my ($vid) = @_;
    trigger_db_prepare($dbh) if ( !$trigger_db_prepared );
    my $logger = Log::Log4perl::get_logger('pf::trigger');
    $trigger_delete_vid_sql->execute($vid) || return (0);
    $logger->debug("triggers vid $vid deleted");
    return (1);
}

sub trigger_delete_all {
    my $logger = Log::Log4perl::get_logger('pf::trigger');
    trigger_db_prepare($dbh) if ( !$trigger_db_prepared );
    $trigger_delete_all_sql->execute() || return (0);
    $logger->debug("All triggers deleted");
    return (1);
}

sub trigger_exist {
    my ( $vid, $tid_start, $tid_end, $type ) = @_;
    trigger_db_prepare($dbh) if ( !$trigger_db_prepared );
    $trigger_exist_sql->execute( $vid, $tid_start, $tid_end, $type )
        || return (0);
    my ($val) = $trigger_exist_sql->fetchrow_array();
    $trigger_exist_sql->finish();
    return ($val);
}

#
# clean input parameters and add to trigger table
#
sub trigger_add {
    my ( $vid, $tid_start, $tid_end, $type ) = @_;
    my $logger = Log::Log4perl::get_logger('pf::trigger');
    trigger_db_prepare($dbh) if ( !$trigger_db_prepared );
    if ( trigger_exist( $vid, $tid_start, $tid_end, $type ) ) {
        $logger->error(
            "attempt to add existing trigger $tid_start $tid_end [$type]");
        return (2);
    }
    $trigger_add_sql->execute( $vid, $tid_start, $tid_end, $type )
        || return (0);
    $logger->debug("trigger $tid_start $tid_end added");
    return (1);
}

sub trigger_scan {
    my ( $addr, $tids ) = @_;
    my $logger = Log::Log4perl::get_logger('pf::trigger');
    eval "use Net::Nessus::ScanLite; 1" || return (0);
    my @return;
    return -1 if ( !$addr );
    my $host = $Config{'scan'}{'host'};
    my $port = $Config{'scan'}{'port'};
    my $user = $Config{'scan'}{'user'};
    my $pass = $Config{'scan'}{'pass'};
    my $ssl  = isenabled( $Config{'scan'}{'ssl'} );
    my @ref  = trigger_view_type("scan");
    my $pluginlist;
    my $holefound = 0;

    if ( !$tids || $tids =~ /^all$/i ) {
        foreach my $row (@ref) {
            for (
                my $i = $row->{'tid_start'};
                $i <= $row->{'tid_end'};
                $i++
                )
            {
                $pluginlist .= "$i;";
            }
        }
        chop($pluginlist);
    } else {
        return -1 if ( $tids !~ /^[\d|;| ]+$/ );
        $pluginlist = $tids;
    }
    return 0 if ( !$pluginlist );
    my $trigger = Net::Nessus::ScanLite->new(
        host => $host,
        port => $port,
        ssl  => $ssl,
    );

    $trigger->preferences(
        {   host_expansion      => 'none',
            safe_checks         => 'yes',
            checks_read_timeout => 1
        }
    );
    $trigger->plugin_set($pluginlist);
    $logger->debug(
        "plug = $pluginlist addr = $addr user =$user port = $port host = $host ssl = $ssl\n"
    );
    if ( $trigger->login( $user, $pass ) ) {
        $logger->info("starting to trigger node(s) $addr");
        $trigger->attack($addr);
        $logger->info( "Address $addr total info: "
                . $trigger->total_info
                . " Total holes: "
                . $trigger->total_holes );
        push @return,
              "Address $addr total info: "
            . $trigger->total_info
            . " Total holes: "
            . $trigger->total_holes . "\n";
        foreach my $info ( $trigger->info_list ) {
            my $srcmac = ip2mac( $info->Host );
            push(
                @return,
                join "|",
                (   0,           $srcmac,
                    $info->Host, $info->ScanID,
                    0,           $info->Port,
                    $info->Description
                )
            );
            $logger->info( "Info ID: "
                    . $info->ScanID
                    . "  Host: "
                    . $info->Host
                    . " Port: "
                    . $info->Port );
            trigger_scan_add($info);
        }
        foreach my $info ( $trigger->hole_list ) {
            my $tid    = $info->ScanID;
            my $srcmac = ip2mac( $info->Host );
            push(
                @return,
                join "|",
                (   1,    $srcmac,     $info->Host,
                    $tid, $info->Port, $info->Description
                )
            );
            $logger->info( "Hole ID: "
                    . $info->ScanID
                    . "  Host: "
                    . $info->Host
                    . " Port: "
                    . $info->Port );
            trigger_scan_add($info);
        }
    } else {
        push( @return,
                  "trigger_scan: Nessus login failed: "
                . $trigger->code . ": "
                . $trigger->error
                . "\n" );
        $logger->error( "Nessus login failed: "
                . $trigger->code . ": "
                . $trigger->error );
    }

    return (@return);
}

sub trigger_scan_add {
    my ($info) = @_;
    my $logger = Log::Log4perl::get_logger('pf::trigger');
    my $tid;
    my $host;
    if ( ref($info) eq 'HASH' ) {
        $tid  = $info->{'ScanID'};
        $host = $info->{'Host'};
    } else {
        $tid  = $info->ScanID;
        $host = $info->Host;
    }
    my $srcmac = ip2mac( $host );
    if ( !$srcmac ) {
        $logger->error( "MAC address for "
                . $host
                . " not found can not add violation" );
        return;
    }
    if ( defined $Config{'scan'}{'live_tids'}
        && grep(
            { $_ eq $tid } split( /\s*,\s*/, $Config{'scan'}{'live_tids'} ) )
        )
    {
        $logger->info( "Trying to add trigger $tid for ($srcmac) ("
                . $host
                . ")" );
        my @trigger_info = trigger_view_enable( $tid, "scan" );
        if ( !scalar(@trigger_info) ) {
            $logger->info(
                "violation not added, no trigger found for scan::${tid} or violation is disabled"
            );
        }
        foreach my $row (@trigger_info) {
            my $vid = $row->{'vid'};
            violation_add( $srcmac, $vid );
        }
    } else {
        $logger->warn( "NOT ADDING Trigger - $tid for $srcmac ("
                . $host
                . ") please add $tid to scan.live_tids if you would like this done"
        );
    }
    return 1;
}

sub trigger_in_range {
    my ( $range, $trigger ) = @_;
    foreach my $element ( split( /\s*,\s*/, $range ) ) {
        if ( $element eq $trigger ) {
            return (1);
        } elsif ( $element =~ /^\d+\s*\-\s*\d+$/ ) {
            my ( $begin, $end ) = split( /\s*\-\s*/, $element );
            if ( $trigger >= $begin && $trigger <= $end ) {
                return (1);
            }
        } else {
            return (0);
        }
    }
    return;
}

=head1 AUTHOR

David LaPorte <david@davidlaporte.org>

Kevin Amorin <kev@amorin.org>

Dominik Gehl <dgehl@inverse.ca>

=head1 COPYRIGHT

Copyright (C) 2005 David LaPorte

Copyright (C) 2005 Kevin Amorin

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
