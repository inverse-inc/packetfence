package pf::violation;

=head1 NAME

pf::violation - module for violation management.

=cut

=head1 DESCRIPTION

pf::violation contains the functions necessary to manage violations: creation, 
deletion, expiration, read info, ...

=head1 CONFIGURATION AND ENVIRONMENT

Read the F<pf.conf> configuration file.

=cut

use strict;
use warnings;
use Log::Log4perl;

our (
    $violation_desc_sql,            $violation_add_sql,
    $violation_exist_sql,           $violation_exist_open_sql,
    $violation_exist_id_sql,        $violation_view_sql,
    $violation_view_all_sql,        $violation_view_top_sql,
    $violation_view_open_sql,       $violation_view_open_desc_sql,
    $violation_view_open_uniq_sql,  $violation_view_open_all_sql,
    $violation_view_all_active_sql, $violation_close_sql,
    $violation_delete_sql,          $violation_modify_sql,
    $violation_grace_sql,           $violation_count_sql,
    $violation_count_trap_sql,      $violation_count_vid_sql,
    $violation_db_prepared
);

BEGIN {
    use Exporter ();
    our ( @ISA, @EXPORT );
    @ISA = qw(Exporter);
    @EXPORT
        = qw(violation_force_close violation_close violation_view violation_view_all violation_view_all_active
        violation_view_open_all violation_add violation_view_open violation_view_open_desc violation_view_open_uniq violation_modify
        violation_trigger violation_count violation_count_trap violation_view_top violation_db_prepare violation_delete violation_exist_open);
}

use pf::config;
use pf::db;
use pf::util;

$violation_db_prepared = 0;

#violation_db_prepare($dbh) if (!$thread);

sub violation_db_prepare {
    my ($dbh) = @_;
    db_connect($dbh);
    my $logger = Log::Log4perl::get_logger('pf::violation');
    $logger->debug("Preparing pf::violation database queries");
    $violation_desc_sql = $dbh->prepare(qq [ desc violation ]);
    $violation_add_sql
        = $dbh->prepare(
        qq [ insert into violation(mac,vid,start_date,release_date,status,ticket_ref,notes) values(?,?,?,?,?,?,?) ]
        );
    $violation_modify_sql
        = $dbh->prepare(
        qq [ update violation set mac=?,vid=?,start_date=?,release_date=?,status=?,ticket_ref=?,notes=? where id=? ]
        );
    $violation_exist_sql
        = $dbh->prepare(
        qq [ select id,mac,vid,start_date,release_date,status,ticket_ref,notes from violation where mac=? and vid=? and start_date=? ]
        );
    $violation_exist_open_sql
        = $dbh->prepare(
        qq [ select id,mac,vid,start_date,release_date,status,ticket_ref,notes from violation where mac=? and vid=? and status="open" order by vid asc ]
        );
    $violation_exist_id_sql
        = $dbh->prepare(
        qq [ select id,mac,vid,start_date,release_date,status,ticket_ref,notes from violation where id=? ]
        );

#$violation_view_sql=$dbh->prepare( qq [ select id,mac,vid,start_date,release_date,status,ticket_ref,notes from violation where mac=? order by start_date desc ]);
    $violation_view_sql
        = $dbh->prepare(
        qq [ select violation.id,violation.mac,node.computername,violation.vid,violation.start_date,violation.release_date,violation.status,violation.ticket_ref,violation.notes from violation,node where violation.mac=node.mac and violation.id=? order by start_date desc ]
        );
    $violation_view_all_sql
        = $dbh->prepare(
        qq [ select violation.id,violation.mac,node.computername,violation.vid,violation.start_date,violation.release_date,violation.status,violation.ticket_ref,violation.notes from violation,node where violation.mac=node.mac ]
        );
    $violation_view_open_sql
        = $dbh->prepare(
        qq [ select id,mac,vid,start_date,release_date,status,ticket_ref,notes from violation where mac=? and status="open" order by start_date desc ]
        );
    $violation_view_open_desc_sql
        = $dbh->prepare(
        qq [ select v.start_date,c.description,v.vid,v.status from violation v inner join class c on v.vid=c.vid where v.mac=? and v.status="open" order by start_date desc ]
        );
    $violation_view_open_uniq_sql = $dbh->prepare(
        qq [ select mac from violation where status="open" group by mac ]);
    $violation_view_open_all_sql
        = $dbh->prepare(
        qq [ select id,mac,vid,start_date,release_date,status,ticket_ref,notes from violation where status="open" ]
        );

#$violation_view_top_sql=$dbh->prepare( qq [ select id,mac,vid,start_date,release_date,status,ticket_ref,notes from violation where mac=? and status="open" order by start_date desc  limit 1]);
    $violation_view_top_sql
        = $dbh->prepare(
        qq [ select id,mac,v.vid,start_date,release_date,status,ticket_ref,notes from violation v, class c where v.vid=c.vid and mac=? and status="open" order by priority desc limit 1]
        );
    $violation_view_all_active_sql
        = $dbh->prepare(
        qq [ select v.mac,v.vid,v.start_date,v.release_date,v.status,v.ticket_ref,v.notes,i.ip,i.start_time,i.end_time from violation v left join iplog i on v.mac=i.mac where v.status="open" and i.end_time=0 group by v.mac]
        );
    $violation_delete_sql
        = $dbh->prepare(qq [ delete from violation where id=? ]);
    $violation_close_sql
        = $dbh->prepare(
        qq [ update violation set release_date=now(),status="closed" where mac=? and vid=? and status="open" ]
        );
    $violation_grace_sql
        = $dbh->prepare(
        qq [ select unix_timestamp(start_date)+grace_period-unix_timestamp(now()) from violation v left join class c on v.vid=c.vid where mac=? and v.vid=? and status="closed" order by start_date desc ]
        );
    $violation_count_sql = $dbh->prepare(
        qq [ select count(*) from violation where mac=? and status="open" ]);
    $violation_count_trap_sql
        = $dbh->prepare(
        qq [ select count(*) from violation, action where violation.vid=action.vid and action.action='trap' and mac=? and status="open" ]
        );
    $violation_count_vid_sql = $dbh->prepare(
        qq [ select count(*) from violation where mac=? and vid=? ]);
    $violation_db_prepared = 1;
    return 1;
}

#
#
sub violation_desc {
    violation_db_prepare($dbh) if ( !$violation_db_prepared );
    return db_data($violation_desc_sql);
}

#
sub violation_modify {
    my ( $id, %data ) = @_;
    violation_db_prepare($dbh) if ( !$violation_db_prepared );
    my $logger = Log::Log4perl::get_logger('pf::violation');
    return (0) if ( !$id );
    my $existing = violation_exist_id($id);

    if ( !$existing ) {
        if ( violation_add( $data{mac}, $data{vid}, %data ) ) {
            $logger->warn(
                "modify of non-existent violation $id attempted - violation added"
            );
            return (2);
        } else {
            $logger->error(
                "modify of non-existent violation $id attempted - violation add failed"
            );
            return (0);
        }
    }
    foreach my $item ( keys(%data) ) {
        $existing->{$item} = $data{$item};
    }

    $logger->info( "violation for mac "
            . $existing->{mac} . " vid "
            . $existing->{vid}
            . " modified" );
    $violation_modify_sql->execute(
        $existing->{mac},        $existing->{vid},
        $existing->{start_date}, $existing->{release_date},
        $existing->{status},     $existing->{ticket_ref},
        $existing->{notes},      $id
    ) || return (0);
    return (1);
}

sub violation_grace {
    my ( $mac, $vid ) = @_;
    violation_db_prepare($dbh) if ( !$violation_db_prepared );
    $violation_grace_sql->execute( $mac, $vid ) || return (0);
    my ($val) = $violation_grace_sql->fetchrow_array();
    $violation_grace_sql->finish();
    $val = 0 if ( !$val );
    return ($val);
}

sub violation_count {
    my ($mac) = @_;
    violation_db_prepare($dbh) if ( !$violation_db_prepared );
    $violation_count_sql->execute($mac) || return (0);
    my ($val) = $violation_count_sql->fetchrow_array();
    $violation_count_sql->finish();
    return ($val);
}

sub violation_count_trap {
    my ($mac) = @_;
    violation_db_prepare($dbh) if ( !$violation_db_prepared );
    $violation_count_trap_sql->execute($mac) || return (0);
    my ($val) = $violation_count_trap_sql->fetchrow_array();
    $violation_count_trap_sql->finish();
    return ($val);
}

sub violation_count_vid {
    my ( $mac, $vid ) = @_;
    violation_db_prepare($dbh) if ( !$violation_db_prepared );
    $violation_count_vid_sql->execute( $mac, $vid ) || return (0);
    my ($val) = $violation_count_vid_sql->fetchrow_array();
    $violation_count_vid_sql->finish();
    return ($val);
}

sub violation_exist {
    my ( $mac, $vid, $start_date ) = @_;
    violation_db_prepare($dbh) if ( !$violation_db_prepared );
    $violation_exist_sql->execute( $mac, $vid, $start_date ) || return (0);
    my $val = $violation_exist_sql->fetchrow_hashref();
    $violation_exist_sql->finish();
    return ($val);
}

sub violation_exist_id {
    my ($id) = @_;
    violation_db_prepare($dbh) if ( !$violation_db_prepared );
    $violation_exist_id_sql->execute($id) || return (0);
    my $val = $violation_exist_id_sql->fetchrow_hashref();
    $violation_exist_id_sql->finish();
    return ($val);
}

sub violation_exist_open {
    my ( $mac, $vid ) = @_;
    violation_db_prepare($dbh) if ( !$violation_db_prepared );
    $violation_exist_open_sql->execute( $mac, $vid ) || return (0);
    my ($val) = $violation_exist_open_sql->fetchrow_array();
    $violation_exist_open_sql->finish();
    return ($val);
}

sub violation_view {
    my ($id) = @_;
    violation_db_prepare($dbh) if ( !$violation_db_prepared );
    return db_data( $violation_view_sql, $id );
}

sub violation_view_all {
    violation_db_prepare($dbh) if ( !$violation_db_prepared );
    return db_data($violation_view_all_sql);
}

sub violation_view_top {
    my ($mac) = @_;
    violation_db_prepare($dbh) if ( !$violation_db_prepared );
    $violation_view_top_sql->execute($mac) || return (0);
    my $ref = $violation_view_top_sql->fetchrow_hashref();
    $violation_view_top_sql->finish();
    return ($ref);
}

sub violation_view_open {
    my ($mac) = @_;
    violation_db_prepare($dbh) if ( !$violation_db_prepared );
    return db_data( $violation_view_open_sql, $mac );
}

sub violation_view_open_desc {
    my ($mac) = @_;
    violation_db_prepare($dbh) if ( !$violation_db_prepared );
    return db_data( $violation_view_open_desc_sql, $mac );
}

sub violation_view_open_uniq {
    violation_db_prepare($dbh) if ( !$violation_db_prepared );
    return db_data($violation_view_open_uniq_sql);
}

sub violation_view_open_all {
    violation_db_prepare($dbh) if ( !$violation_db_prepared );
    return db_data($violation_view_open_all_sql);
}

sub violation_view_all_active {
    violation_db_prepare($dbh) if ( !$violation_db_prepared );
    return db_data($violation_view_all_active_sql);
}

#
sub violation_add {
    my ( $mac, $vid, %data ) = @_;
    violation_db_prepare($dbh) if ( !$violation_db_prepared );
    my $logger = Log::Log4perl::get_logger('pf::violation');
    return (0) if ( !$vid );

    #print Dumper(%data);
    #defaults
    $data{start_date} = mysql_date()
        if ( !defined $data{start_date} || !$data{start_date} );
    $data{release_date} = 0 if ( !defined $data{release_date} );
    $data{status} = "open" if ( !defined $data{status} || !$data{status} );
    $data{notes}  = ""     if ( !defined $data{notes} );
    $data{ticket_ref} = "" if ( !defined $data{ticket_ref} );

    # Is this MAC and ID aready in DB?  if so don't add another
    if ( violation_exist_open( $mac, $vid ) ) {
        $logger->warn("violation $vid already exists for $mac");
        return (1);
    }

    my $latest_violation = ( violation_view_open($mac) )[0];
    my $latest_vid       = $latest_violation->{'vid'};
    if ($latest_vid) {

        # don't add a hostscan if violation exists
        if ( $vid == $portscan_sid ) {
            $logger->warn(
                "hostscan detected from $mac, but violation $latest_vid exists - ignoring"
            );
            return (1);
        }

        #replace UNKNOWN hostscan with known violation
        if ( $latest_vid == $portscan_sid ) {
            $logger->info(
                "violation $vid detected for $mac - updating existing hostscan entry"
            );
            violation_force_close( $mac, $portscan_sid );
        }
    }

    #  has this mac registered if not register for violation?
    require pf::node;
    if ( !pf::node::node_exist($mac) ) {
        pf::node::node_add_simple($mac);
    } else {

        # not a new violation check violation
        my ($remaining_time) = violation_grace( $mac, $vid );
        if ( $remaining_time > 0 ) {
            $logger->info(
                "$remaining_time grace remaining on violation $vid for node $mac"
            );
            return (1);
        } else {
            $logger->info("grace expired on violation $vid for node $mac");
        }
    }

    # insert violation into db
    $violation_add_sql->execute( $mac, $vid, $data{start_date},
        $data{release_date}, $data{status}, $data{ticket_ref}, $data{notes} )
        || return (0);
    $logger->info("violation $vid added for $mac");
    require pf::action;
    pf::action::action_execute( $mac, $vid, $data{notes} );
    return (1);
}

sub violation_trigger {
    my ( $mac, $tid, $type, %data ) = @_;
    my $logger = Log::Log4perl::get_logger('pf::violation');
    return (0) if ( !$tid );
    $type = lc($type);

    require pf::trigger;
    my @trigger_info = pf::trigger::trigger_view_enable( $tid, $type );
    if ( !scalar(@trigger_info) ) {
        $logger->debug("violation not added, no trigger found for ${type}::${tid} or violation is disabled");
        return 0;
    }
    foreach my $row (@trigger_info) {
	next unless (ref($row) eq 'HASH');
        my $vid = $row->{'vid'};

        if (whitelisted_mac($mac)) {
            $logger->info("violation: $vid - MAC $mac : violation not added, $mac is whitelisted !");

        } elsif (!valid_mac($mac)) {
            $logger->info("violation: $vid - MAC $mac : violation not added, $mac is not valid !");

        } elsif (!trappable_mac($mac)) {
            $logger->info("violation: $vid - MAC $mac : violation not added, $mac is not trappable !");

        # if we were given an IP as additionnal violation trigger info
        # test whether this ip is trappable or not
        } elsif (defined($data{ip}) && !trappable_ip($data{ip})) {
            $logger->info("violation: $vid - MAC $mac : violation not added, IP ".$data{ip}." is not trappable !");

        } else  {
            # TODO: fix hardcoded path, should use installdir something instead
            $logger->info("calling /usr/local/pf/bin/pfcmd violation add vid=$vid,mac=$mac");
            # forking a pfcmd because it will call a vlan flip if needed
            `/usr/local/pf/bin/pfcmd violation add vid=$vid,mac=$mac`;
        }
    }
    return 1;
}

sub violation_delete {
    my ($id) = @_;
    violation_db_prepare($dbh) if ( !$violation_db_prepared );
    $violation_delete_sql->execute($id) || return (0);
    return (0);
}

#return -1 on failure, because grace=0 is unlimited
#
sub violation_close {
    my ( $mac, $vid ) = @_;
    violation_db_prepare($dbh) if ( !$violation_db_prepared );
    my $logger = Log::Log4perl::get_logger('pf::violation');
    require pf::class;
    my $class_info = pf::class::class_view($vid);

    # check auto_enable = 'N'
    if ( $class_info->{'auto_enable'} =~ /^N$/i ) {
        return (-1);
    }

    #check the number of violations
    my $num = violation_count_vid( $mac, $vid );
    my $max = $class_info->{'max_enables'};

    if ( $num <= $max || $max == 0 ) {
        if ( !( $Config{'network'}{'mode'} =~ /vlan/i ) ) {
            require pf::iptables;
            pf::iptables::iptables_unmark_node( $mac, $vid );
        }
        my $grace = $class_info->{'grace_period'};
        $violation_close_sql->execute( $mac, $vid ) || return (0);
        $logger->info("violation $vid closed for $mac");
        return ($grace);
    }
    return (-1);
}

# use force close on non-trap violations
#
sub violation_force_close {
    my ( $mac, $vid ) = @_;
    violation_db_prepare($dbh) if ( !$violation_db_prepared );
    my $logger = Log::Log4perl::get_logger('pf::violation');

    #iptables_unmark_node($mac, $vid);
    $violation_close_sql->execute( $mac, $vid ) || return (0);
    $logger->warn(
        "violation $vid closed for $mac since it's a non-trap violation");
    return (1);
}

=head1 AUTHOR

David LaPorte <david@davidlaporte.org>

Kevin Amorin <kev@amorin.org>

Olivier Bilodeau <obilodeau@inverse.ca>

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
