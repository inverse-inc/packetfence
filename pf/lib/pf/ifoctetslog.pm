#
# Copyright 2005 David LaPorte <david@davidlaporte.org>
# Copyright 2005 Kevin Amorin <kev@amorin.org>
# Copyright 2007-2008 Inverse groupe conseil <dgehl@inverse.ca>
#
# See the enclosed file COPYING for license information (GPL).
# If you did not receive this file, see
# http://www.fsf.org/licensing/licenses/gpl.html.
#

package pf::ifoctetslog;

use strict;
use warnings;

our (
    $ifoctetslog_history_mac_sql,
    $ifoctetslog_history_mac_start_end_sql,
    $ifoctetslog_history_user_sql,
    $ifoctetslog_history_user_start_end_sql,
    $ifoctetslog_history_switchport_sql,
    $ifoctetslog_history_switchport_start_end_sql,

    $ifoctetslog_insert_sql,

    $ifoctetslog_db_prepared
);

BEGIN {
    use Exporter ();
    our ( @ISA, @EXPORT );
    @ISA    = qw(Exporter);
    @EXPORT = qw(
        ifoctetslog_db_prepare

        ifoctetslog_history_mac
        ifoctetslog_history_user
        ifoctetslog_history_switchport

        ifoctetslog_graph_mac
        ifoctetslog_graph_user
        ifoctetslog_graph_switchport

        ifoctetslog_insert
    );
}

use Date::Parse;
use Log::Log4perl;
use Net::MAC;
use pf::db;

$ifoctetslog_db_prepared = 0;

#ifoctetslog_db_prepare($dbh) if (!$thread);

sub ifoctetslog_db_prepare {
    my ($dbh) = @_;
    db_connect($dbh);
    my $logger = Log::Log4perl::get_logger('pf::ifoctetslog');
    $logger->debug("Preparing pf::ifoctetslog database queries");
    $ifoctetslog_history_mac_sql
        = $dbh->prepare(
        qq [ select switch,port,read_time,mac,ifInOctets,ifOutOctets from ifoctetslog where mac=? order by read_time desc ]
        );
    $ifoctetslog_history_mac_start_end_sql
        = $dbh->prepare(
        qq [ select switch,port,read_time,mac,ifInOctets,ifOutOctets from ifoctetslog where mac=? and read_time >= from_unixtime(?) and read_time <= from_unixtime(?) order by read_time desc ]
        );
    $ifoctetslog_history_user_sql
        = $dbh->prepare(
        qq [ select ifoctetslog.switch,ifoctetslog.port,read_time,ifoctetslog.mac,ifInOctets,ifOutOctets from ifoctetslog, node where ifoctetslog.mac=node.mac and pid=? order by mac asc, read_time desc ]
        );
    $ifoctetslog_history_user_start_end_sql
        = $dbh->prepare(
        qq [ select ifoctetslog.switch,ifoctetslog.port,read_time,ifoctetslog.mac,ifInOctets,ifOutOctets from ifoctetslog, node where ifoctetslog.mac=node.mac and pid=? and read_time >= from_unixtime(?) and read_time <= from_unixtime(?) order by mac asc, read_time desc ]
        );

    $ifoctetslog_history_switchport_sql
        = $dbh->prepare(
        qq [ select switch,port,read_time,mac,ifInOctets,ifOutOctets from ifoctetslog where switch=? and port=? order by read_time desc ]
        );
    $ifoctetslog_history_switchport_start_end_sql
        = $dbh->prepare(
        qq [ select switch,port,read_time,mac,ifInOctets,ifOutOctets from ifoctetslog where switch=? and port=? and read_time >= from_unixtime(?) and read_time <= from_unixtime(?) order by read_time desc ]
        );

    $ifoctetslog_insert_sql
        = $dbh->prepare(
        qq [ INSERT INTO ifoctetslog (switch, port, read_time, mac, ifInOctets, ifOutOctets) VALUES(?,?,NOW(),?,?,?) ]
        );

    $ifoctetslog_db_prepared = 1;

}

sub ifoctetslog_history_mac {
    my ( $mac, %params ) = @_;
    ifoctetslog_db_prepare($dbh) if ( !$ifoctetslog_db_prepared );
    my $tmpMAC = Net::MAC->new( 'mac' => $mac );
    $mac = $tmpMAC->as_IEEE();
    my @raw_data;
    my @data;
    if ( exists( $params{'start_time'} ) && exists( $params{'end_time'} ) ) {
        $ifoctetslog_history_mac_start_end_sql->execute( $mac,
            $params{'start_time'}, $params{'end_time'} )
            || return (0);
        @raw_data = db_data($ifoctetslog_history_mac_start_end_sql);
    } else {
        $ifoctetslog_history_mac_sql->execute($mac) || return (0);
        @raw_data = db_data($ifoctetslog_history_mac_sql);
    }
    my $previousLine;
    foreach my $line ( reverse @raw_data ) {
        $line->{'throughPutIn'}  = 0;
        $line->{'throughPutOut'} = 0;
        if ( exists( $previousLine->{'read_time'} ) ) {
            my $timeDiff = str2time( $line->{'read_time'} )
                - str2time( $previousLine->{'read_time'} );
            if (   ( $previousLine->{'switch'} eq $line->{'switch'} )
                && ( $previousLine->{'port'} == $line->{'port'} ) )
            {
                $line->{'throughPutIn'}
                    = calculateThroughPut( $line->{'ifInOctets'},
                    $previousLine->{'ifInOctets'}, $timeDiff );
                $line->{'throughPutOut'}
                    = calculateThroughPut( $line->{'ifOutOctets'},
                    $previousLine->{'ifOutOctets'}, $timeDiff );
            }
        }
        push @data, $line;
        $previousLine = $line;
    }
    return @data;
}

sub ifoctetslog_history_user {
    my ( $user, %params ) = @_;
    ifoctetslog_db_prepare($dbh) if ( !$ifoctetslog_db_prepared );
    my @raw_data;
    my @data;
    if ( exists( $params{'start_time'} ) && exists( $params{'end_time'} ) ) {
        $ifoctetslog_history_user_start_end_sql->execute( $user,
            $params{'start_time'}, $params{'end_time'} )
            || return (0);
        @raw_data = db_data($ifoctetslog_history_user_start_end_sql);
    } else {
        $ifoctetslog_history_user_sql->execute($user) || return (0);
        @raw_data = db_data($ifoctetslog_history_user_sql);
    }
    my $previousLine;
    foreach my $line ( reverse @raw_data ) {
        $line->{'throughPutIn'}  = 0;
        $line->{'throughPutOut'} = 0;
        if (   exists( $previousLine->{'read_time'} )
            && exists( $previousLine->{'mac'} )
            && exists( $line->{'mac'} )
            && ( $previousLine->{'mac'} eq $line->{'mac'} ) )
        {
            my $timeDiff = str2time( $line->{'read_time'} )
                - str2time( $previousLine->{'read_time'} );
            if (   ( $previousLine->{'switch'} eq $line->{'switch'} )
                && ( $previousLine->{'port'} == $line->{'port'} ) )
            {
                $line->{'throughPutIn'}
                    = calculateThroughPut( $line->{'ifInOctets'},
                    $previousLine->{'ifInOctets'}, $timeDiff );
                $line->{'throughPutOut'}
                    = calculateThroughPut( $line->{'ifOutOctets'},
                    $previousLine->{'ifOutOctets'}, $timeDiff );
            }
        }
        push @data, $line;
        $previousLine = $line;
    }
    return @data;
}

sub ifoctetslog_graph_switchport {
    my ( $switch, %params ) = @_;
    my @tmp_data = ifoctetslog_history_switchport( $switch, %params );
    return convertHistoryToGraph( $params{'start_time'}, $params{'end_time'},
        @tmp_data );
}

sub ifoctetslog_graph_mac {
    my ( $mac, %params ) = @_;
    my @tmp_data = ifoctetslog_history_mac( $mac, %params );
    return convertHistoryToGraph( $params{'start_time'}, $params{'end_time'},
        @tmp_data );
}

sub ifoctetslog_graph_user {
    my ( $user, %params ) = @_;
    my @tmp_data = ifoctetslog_history_user( $user, %params );
    return convertHistoryToGraph( $params{'start_time'}, $params{'end_time'},
        @tmp_data );
}

sub ifoctetslog_history_switchport {
    my ( $switch, %params ) = @_;
    ifoctetslog_db_prepare($dbh) if ( !$ifoctetslog_db_prepared );
    my @raw_data;
    my @data;
    if ( exists( $params{'start_time'} ) && exists( $params{'end_time'} ) ) {
        $ifoctetslog_history_switchport_start_end_sql->execute( $switch,
            $params{'ifIndex'}, $params{'start_time'}, $params{'end_time'} )
            || return (0);
        @raw_data = db_data($ifoctetslog_history_switchport_start_end_sql);
    } else {
        $ifoctetslog_history_switchport_sql->execute( $switch,
            $params{'ifIndex'} )
            || return (0);
        @raw_data = db_data($ifoctetslog_history_switchport_sql);
    }
    my $previousLine;
    foreach my $line ( reverse @raw_data ) {
        $line->{'throughPutIn'}  = 0;
        $line->{'throughPutOut'} = 0;
        if ( exists( $previousLine->{'read_time'} ) ) {
            my $timeDiff = str2time( $line->{'read_time'} )
                - str2time( $previousLine->{'read_time'} );
            $line->{'throughPutIn'}
                = calculateThroughPut( $line->{'ifInOctets'},
                $previousLine->{'ifInOctets'}, $timeDiff );
            $line->{'throughPutOut'}
                = calculateThroughPut( $line->{'ifOutOctets'},
                $previousLine->{'ifOutOctets'}, $timeDiff );
        }
        push @data, $line;
        $previousLine = $line;
    }
    return @data;
}

sub ifoctetslog_insert {
    my ( $switch, $ifIndex, $mac, $ifInOctets, $ifOutOctets ) = @_;
    ifoctetslog_db_prepare($dbh) if ( !$ifoctetslog_db_prepared );
    $ifoctetslog_insert_sql->execute( $switch, $ifIndex, $mac, $ifInOctets,
        $ifOutOctets )
        || return (0);
    return (1);
}

sub calculateThroughPut {
    my ( $currentOctets, $previousOctets, $timeDiff ) = @_;
    if ( $currentOctets - $previousOctets >= 0 ) {
        return sprintf( "%.2f",
            ( $currentOctets - $previousOctets ) / $timeDiff );
    } else {
        return sprintf( "%.2f", $currentOctets / $timeDiff );
    }
}

sub convertHistoryToGraph {
    my ( $start_time, $end_time, @tmp_data ) = @_;
    my $timespan              = $end_time - $start_time;
    my $timeDiffBetweenPoints = 300;
    if ( $timespan > 86400 ) {    #larger than a day
        $timeDiffBetweenPoints = $timespan / 288;
    }

    my @data;
    my $pos = 0;
    my $current_timestamp;
    my $ifInOctetsStart  = 0;
    my $ifInOctetsEnd    = 0;
    my $ifOutOctetsStart = 0;
    my $ifOutOctetsEnd   = 0;
    my $start_timestamp  = 0;
    my $end_timestamp    = 0;
    my $timeStampStart   = 0;

    #use Data::Dumper;
    #print Dumper(@tmp_data);
    for (
        $current_timestamp = $start_time;
        $current_timestamp < $end_time;
        $current_timestamp += $timeDiffBetweenPoints
        )
    {
        $start_timestamp = $current_timestamp;
        $end_timestamp   = $current_timestamp + $timeDiffBetweenPoints;
        my ( $firstPosInRange, $lastPosInRange )
            = getFirstAndLastPosInRange( $start_timestamp, $end_timestamp,
            $pos, @tmp_data );

#print "start_time is $start_time\n";
#print "end_time is $end_time\n";
#print "first data point is " . str2time($tmp_data[0]->{'read_time'}) . " (" . $tmp_data[0]->{'read_time'} . ")\n";
#print "last data point is " . str2time($tmp_data[scalar(@tmp_data)-1]->{'read_time'}) . " (" . $tmp_data[scalar(@tmp_data)-1]->{'read_time'} . ")\n";
#print "firstPos is $firstPosInRange\n";
#print "lastPos is $lastPosInRange\n";
#print "start_timestamp is $start_timestamp\n";
#print "end_timestamp is $end_timestamp\n";
        if ( $lastPosInRange != -1 ) {

#print "firstPos timestamp is " . str2time($tmp_data[$firstPosInRange]->{'read_time'}) . " (" . $tmp_data[$firstPosInRange]->{'read_time'} . ")\n";
#print "endPos timestamp is " . str2time($tmp_data[$lastPosInRange]->{'read_time'}) . " (" . $tmp_data[$lastPosInRange]->{'read_time'} . ")\n";
            $pos = $lastPosInRange;
            if ( $firstPosInRange == $lastPosInRange ) {
                push @data,
                    {
                    'throughPutOut' => $tmp_data[$pos]->{'throughPutOut'},
                    'throughPutIn'  => $tmp_data[$pos]->{'throughPutIn'},
                    'mydate'        => $tmp_data[$pos]->{'read_time'}
                    };
            } else {
                push @data,
                    {
                    'throughPutOut' => (
                        (         $tmp_data[$lastPosInRange]->{'ifOutOctets'}
                                - $tmp_data[$firstPosInRange]->{'ifOutOctets'}
                        ) / (
                            str2time(
                                $tmp_data[$lastPosInRange]->{'read_time'}
                                ) - str2time(
                                $tmp_data[$firstPosInRange]->{'read_time'}
                                )
                        )
                    ),
                    'throughPutIn' => (
                        (         $tmp_data[$lastPosInRange]->{'ifInOctets'}
                                - $tmp_data[$firstPosInRange]->{'ifInOctets'}
                        ) / (
                            str2time(
                                $tmp_data[$lastPosInRange]->{'read_time'}
                                ) - str2time(
                                $tmp_data[$firstPosInRange]->{'read_time'}
                                )
                        )
                    ),
                    'mydate' => $tmp_data[$lastPosInRange]->{'read_time'}
                    };
            }
        } else {
            push @data,
                {
                'throughPutOut' => 0,
                'throughPutIn'  => 0,
                'mydate'        => POSIX::strftime(
                    "%Y-%m-%d %H:%M:%S",
                    localtime($current_timestamp)
                )
                };
        }
    }
    return @data;
}

sub getFirstAndLastPosInRange {
    my ( $start_time, $end_time, $start_pos, @tmp_data ) = @_;
    my $pos = $start_pos;
    my @firstAndLastPos = ( -1, -1 );
    while (( $pos < scalar(@tmp_data) )
        && ( $start_time > str2time( $tmp_data[$pos]->{'read_time'} ) ) )
    {
        $pos++;
    }
    if (   ( $pos < scalar(@tmp_data) )
        && ( $end_time >= str2time( $tmp_data[$pos]->{'read_time'} ) ) )
    {
        $firstAndLastPos[0] = $pos;
    }
    if ( $firstAndLastPos[0] != -1 ) {
        while (( $pos < scalar(@tmp_data) )
            && ( $end_time > str2time( $tmp_data[$pos]->{'read_time'} ) ) )
        {
            $pos++;
        }
        if (   ( $pos > 0 )
            && ( $pos - 1 < scalar(@tmp_data) )
            && ( $start_time
                <= str2time( $tmp_data[ $pos - 1 ]->{'read_time'} ) )
            )
        {
            $firstAndLastPos[1] = $pos - 1;
        } else {
            $firstAndLastPos[0] = -1;
        }
    }
    return @firstAndLastPos;
}

1;
