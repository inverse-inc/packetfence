package pf::action;

=head1 NAME

pf::action - module to handle violation actions

=cut

=head1 DESCRIPTION

pf::action contains the functions necessary to manage all the different 
actions (email, log, trap, ...) triggered when a violation is created, 
opened, closed or deleted.

=head1 CONFIGURATION AND ENVIRONMENT

Read the F<pf.conf> configuration file.

=cut

use strict;
use warnings;

our (
    $action_add_sql,   $action_delete_sql, $action_delete_all_sql,
    $action_exist_sql, $action_view_sql,   $action_view_all_sql,
    $action_db_prepared
);

BEGIN {
    use Exporter ();
    our ( @ISA, @EXPORT );
    @ISA = qw(Exporter);
    @EXPORT
        = qw(action_db_prepare action_add action_view action_view_all action_delete action_delete_all action_execute action_log);
}

use Log::Log4perl;
use pf::config;
use pf::util;
use pf::db;
use pf::class qw(class_view class_view_actions);

$action_db_prepared = 0;

#action_db_prepare($dbh) if (!$thread);

sub action_db_prepare {
    my ($dbh) = @_;
    db_connect($dbh);
    my $logger = Log::Log4perl::get_logger('pf::action');
    $logger->debug("Preparing pf::action database queries");
    $action_add_sql
        = $dbh->prepare(qq[ insert into action(vid,action) values(?,?) ]);
    $action_delete_sql
        = $dbh->prepare(qq[ delete from action where vid=? and action=? ]);
    $action_delete_all_sql
        = $dbh->prepare(qq[ delete from action where vid=? ]);
    $action_exist_sql = $dbh->prepare(
        qq[ select vid,action from action where vid=? and action=? ]);
    $action_view_sql = $dbh->prepare(
        qq[ select vid,action from action where vid=? and action=? ]);
    $action_view_all_sql
        = $dbh->prepare(qq[ select vid,action from action where vid=? ]);
    $action_db_prepared = 1;
}

sub action_exist {
    my ( $vid, $action ) = @_;
    action_db_prepare($dbh) if ( !$action_db_prepared );
    $action_exist_sql->execute( $vid, $action ) || return (0);
    my ($val) = $action_exist_sql->fetchrow_array();
    $action_exist_sql->finish();
    return ($val);
}

sub action_add {
    my ( $vid, $action ) = @_;
    action_db_prepare($dbh) if ( !$action_db_prepared );
    my $logger = Log::Log4perl::get_logger('pf::action');
    if ( action_exist( $vid, $action ) ) {
        $logger->info("attempt to add existing action $action to class $vid");
        return (2);
    }
    $action_add_sql->execute( $vid, $action ) || return (0);
    $logger->info("action $action added to class $vid");
    return (1);
}

sub action_view {
    my ( $vid, $action ) = @_;
    action_db_prepare($dbh) if ( !$action_db_prepared );
    $action_view_sql->execute( $vid, $action ) || return (0);
    my $ref = $action_view_sql->fetchrow_hashref();

    # just get one row and finish
    $action_view_sql->finish();
    return ($ref);
}

sub action_view_all {
    my ($vid) = @_;
    action_db_prepare($dbh) if ( !$action_db_prepared );
    return db_data( $action_view_all_sql, $vid );
}

sub action_delete {
    my ( $vid, $action ) = @_;
    action_db_prepare($dbh) if ( !$action_db_prepared );
    my $logger = Log::Log4perl::get_logger('pf::action');
    $action_delete_sql->execute( $vid, $action ) || return (0);
    $logger->info("action $action deleted from class $vid");
    return (1);
}

sub action_delete_all {
    my ($vid) = @_;
    action_db_prepare($dbh) if ( !$action_db_prepared );
    my $logger = Log::Log4perl::get_logger('pf::action');
    $action_delete_all_sql->execute($vid) || return (0);
    $logger->info("all actions for class $vid deleted");
    return (1);
}

sub action_api {
    my ( $mac, $vid, $external_id ) = @_;
    my $class_info = class_view($vid);
    my @args       = (
        $Config{'paths'}{ 'external' . $external_id },
        $mac, $class_info->{'description'}
    );
    system(@args);
}

sub action_execute {
    my ( $mac, $vid, $notes ) = @_;
    my $logger     = Log::Log4perl::get_logger('pf::action');
    my $leave_open = 0;
    my @actions    = class_view_actions($vid);
    foreach my $row (@actions) {
        my $action = $row->{'action'};
        $logger->info("executing action '$action' on class $vid");
        if ( $action =~ /^trap$/i ) {
            $leave_open = 1;
            action_trap( $mac, $vid );
        } elsif ( $action =~ /^email$/i ) {
            action_email( $mac, $vid, $notes );
        } elsif ( $action =~ /^log$/i ) {
            action_log( $mac, $vid );
        } elsif ( $action =~ /^external(\d+)$/i ) {
            action_api( $mac, $vid, $1 );
        } elsif ( $action =~ /^winpopup$/i ) {
            action_winpopup( $mac, $vid );
        } elsif ( $action =~ /^autoreg$/i ) {
            if ( isenabled( $Config{'trapping'}{'registration'} ) ) {
                require pf::node;
                pf::node::node_register_auto($mac);
            } else {
                $logger->warn(
                    "autoreg action defined for violation $vid, but registration disabled"
                );
            }
        } else {
            $logger->error( "unknown action '$action' for class $vid", 1 );
        }
    }
    if ( !$leave_open ) {
        require pf::violation;
        pf::violation::violation_force_close( $mac, $vid );
    }
    return (1);
}

sub action_email {
    my ( $mac, $vid, $notes ) = @_;
    my %message;

    require pf::lookup::node;
    my $class_info  = class_view($vid);
    my $description = $class_info->{'description'};

    $message{'subject'} = "$description detection on $mac";
    $message{'message'} = "Detect  : $description\n";
    $message{'message'} .= "$notes\n";
    $message{'message'} .= pf::lookup::node::lookup_node($mac);

    pfmailer(%message);
}

sub action_log {
    my ( $mac, $vid ) = @_;
    my $logger = Log::Log4perl::get_logger('pf::action');
    require pf::iplog;
    my $ip = pf::iplog::mac2ip($mac) || 0;

    my $class_info  = class_view($vid);
    my $description = $class_info->{'description'};

    #my $violation_info = violation_view($mac, $vid);
    #my $date = $violation_info->{'start_date'};
    my $date = mysql_date();

    my $logfile = $Config{'alerting'}{'log'};
    $logger->info(
        "$logfile $date: $description ($vid) detected on node $mac ($ip)");
    my $log_fh;
    open( $log_fh, '>>', "$logfile" )
        || $logger->logcroak("Unable to open $logfile for append: $!");
    print {$log_fh}
        "$date: $description ($vid) detected on node $mac ($ip)\n";
    close($log_fh);
}

sub action_trap {
    my ( $mac, $vid ) = @_;
    my $logger = Log::Log4perl::get_logger('pf::action');
    if ( !( $Config{'network'}{'mode'} =~ /vlan/i ) ) {
        require pf::iptables;
        if ( !pf::iptables::iptables_mark_node( $mac, $vid ) ) {
            $logger->error("unable to mark $mac with $vid");
            return (0);
        }
    }

    # Let pfmon do this...
    #return(trapmac($mac)) if ($Config{'network'}{'mode'} =~ /arp/i);
}

sub action_winpopup {
    my ( $mac, $vid ) = @_;
    my $logger = Log::Log4perl::get_logger('pf::action');

    eval "use Net::NetSend qw(:all); 1" || return (0);
    eval "use Net::NBName; 1"           || return (0);

    require pf::lookup::node;
    my $class_info  = class_view($vid);
    my $description = $class_info->{'description'};
    my $message     = "$description detection on $mac " 
                      . pf::lookup::node::lookup_node($mac);

    my $nb = Net::NBName->new;
    my $nq = $nb->name_query( $Config{'alerting'}{'wins_server'},
        $Config{'alerting'}{'admin_netbiosname'}, 0x00 );
    if ($nq) {
        my $admin_addr_obj = ( $nq->addresses )[0];
        my $admin_ip       = $admin_addr_obj->address;
        if (!sendMsg(
                $Config{'alerting'}{'admin_netbiosname'},
                'Packetfence', $admin_ip, $message, 0
            )
            )
        {
            $logger->error("Unable to send winpopup to $admin_ip");
        }
    } else {
        $logger->error("Unable to resolve NetBIOS->IP to send winpopup");
    }

}

=head1 AUTHOR

David Laporte <david@davidlaporte.org>

Kevin Amorin <kev@amorin.org>

Dominik Gehl <dgehl@inverse.ca>

=head1 COPYRIGHT

Copyright (C) 2005 David Laporte

Copyright (C) 2005 Kevin Amorin

Copyright (C) 2007-2008 Inverse groupe conseil

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
