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
use Log::Log4perl;
use Readonly;
use pf::node;

use constant ACTION => 'action';

# Action types constants
#FIXME port all hard-coded strings to these constants
Readonly::Scalar our $AUTOREG => 'autoreg';
Readonly::Scalar our $UNREG => 'unreg';
Readonly::Scalar our $TRAP => 'trap';
Readonly::Scalar our $EMAIL => 'email';
Readonly::Scalar our $LOG => 'log';
Readonly::Scalar our $EXTERNAL => 'external';
Readonly::Scalar our $WINPOPUP => 'winpopup';
Readonly::Scalar our $CLOSE => 'close';
Readonly::Scalar our $ROLE => 'role';

Readonly::Array our @VIOLATION_ACTIONS =>
  (
   $AUTOREG,
   $UNREG,
   $EMAIL,
   $TRAP,
   $LOG,
   $EXTERNAL,
   $WINPOPUP,
   $CLOSE,
   $ROLE,
  );

BEGIN {
    use Exporter ();
    our ( @ISA, @EXPORT );
    @ISA = qw(Exporter);
    @EXPORT = qw(
        $action_db_prepared  action_db_prepare

        action_add           action_exist
        action_view          action_view_all
        action_delete        action_delete_all
        action_execute       action_log
        action_close
    );
}

use pf::config;
use pf::db;
use pf::util;
use pf::class qw(class_view class_view_actions);
use pf::violation qw(violation_force_close);

# The next two variables and the _prepare sub are required for database handling magic (see pf::db)
our $action_db_prepared = 0;
# in this hash reference we hold the database statements. We pass it to the query handler and he will repopulate
# the hash if required
our $action_statements = {};

sub action_db_prepare {
    my $logger = Log::Log4perl::get_logger('pf::action');
    $logger->debug("Preparing pf::action database queries");

    $action_statements->{'action_add_sql'} = get_db_handle()->prepare(qq[ insert into action(vid,action) values(?,?) ]);

    $action_statements->{'action_delete_sql'} = get_db_handle()->prepare(qq[ delete from action where vid=? and action=? ]);

    $action_statements->{'action_delete_all_sql'} = get_db_handle()->prepare(qq[ delete from action where vid=? ]);

    $action_statements->{'action_exist_sql'} = get_db_handle()->prepare(
        qq[ select vid,action from action where vid=? and action=? ]);

    $action_statements->{'action_view_sql'} = get_db_handle()->prepare(
        qq[ select vid,action from action where vid=? and action=? ]);

    $action_statements->{'action_view_all_sql'} = get_db_handle()->prepare(qq[ select vid,action from action where vid=? ]);

    $action_db_prepared = 1;
}

sub action_exist {
    my ($vid, $action) = @_;
    my $query = db_query_execute(ACTION, $action_statements, 'action_exist_sql', $vid, $action) || return (0);
    my ($val) = $query->fetchrow_array();
    $query->finish();

    return ($val);
}

sub action_add {
    my ($vid, $action) = @_;
    my $logger = Log::Log4perl::get_logger('pf::action');
    if ( action_exist( $vid, $action ) ) {
        $logger->warn("attempt to add existing action $action to class $vid");
        return (2);
    }
    db_query_execute(ACTION, $action_statements, 'action_add_sql', $vid, $action) || return (0);
    $logger->debug("action $action added to class $vid");

    return (1);
}

sub action_view {
    my ($vid, $action) = @_;

    my $query = db_query_execute(ACTION, $action_statements, 'action_view_sql', $vid, $action) || return (0);
    my $ref = $query->fetchrow_hashref();

    # just get one row and finish
    $query->finish();

    return ($ref);
}

sub action_view_all {
    my ($vid) = @_;

    return db_data(ACTION, $action_statements, 'action_view_all_sql', $vid );
}

sub action_delete {
    my ($vid, $action) = @_;
    my $logger = Log::Log4perl::get_logger('pf::action');
    db_query_execute(ACTION, $action_statements, 'action_delete_sql', $vid, $action) || return (0);
    $logger->debug("action $action deleted from class $vid");

    return (1);
}

sub action_delete_all {
    my ($vid) = @_;
    my $logger = Log::Log4perl::get_logger('pf::action');
    db_query_execute(ACTION, $action_statements, 'action_delete_all_sql', $vid) || return (0);
    $logger->debug("all actions for class $vid deleted");

    return (1);
}

# TODO what is that? Isn't it dangerous?
sub action_api {
    my ($mac, $vid, $external_id) = @_;
    my $class_info = class_view($vid);
    my @args =
      (
       $Config{'paths'}{ 'external' . $external_id },
       $mac, $class_info->{'description'}
    );
    system(@args);
}

sub action_execute {
    my ($mac, $vid, $notes) = @_;
    my $logger = Log::Log4perl::get_logger('pf::action');
    my $leave_open = 0;
    my @actions = class_view_actions($vid);
    @actions = sort { $b->{action} cmp $a->{action} } @actions;
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
            action_autoregister($mac, $vid);
        } elsif ( $action =~ /^close$/i ) {
            action_close( $mac, $vid );
        } elsif ( $action =~ /^role$/i ) {
            action_role( $mac, $vid );
        } elsif ( $action =~ /^unreg$/i ) {
            action_unreg( $mac, $vid );
        } else {
            $logger->error( "unknown action '$action' for class $vid", 1 );
        }
    }
    if ( !$leave_open ) {
        $logger->info("this is a non-trap violation, closing violation entry now");
        require pf::violation;
        pf::violation::violation_force_close( $mac, $vid );
    }
    return (1);
}

sub action_role {
    my ($mac, $vid) = @_;
    my %info;

    my $class_info = class_view($vid);
    $info{'category'} = $class_info->{'target_category'};

    node_modify($mac, %info);
}

sub action_unreg {
    my ($mac, $vid) = @_;

    node_deregister($mac);
}

sub action_email {
    my ($mac, $vid, $notes) = @_;
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
    my ($mac, $vid) = @_;
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
    my ($mac, $vid) = @_;
    pf::enforcement::reevaluate_access( $mac, "manage_vopen");
}

sub action_winpopup {
    my ($mac, $vid) = @_;
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

sub action_autoregister {
    my ($mac, $vid) = @_;
    my $logger = Log::Log4perl::get_logger('pf::action');

    if (isenabled($Config{'trapping'}{'registration'})) {

        require pf::vlan::custom;
        my $vlan_obj = new pf::vlan::custom();
        if ($vlan_obj->shouldAutoRegister($mac, 0, 1)) {

            # auto-register
            # sorry for the weird call, check pf::vlan for this sub's parameters
            my %autoreg_node_defaults = $vlan_obj->getNodeInfoForAutoReg(undef, undef, $mac, undef, 0, 1);
            $logger->debug("auto-registering node $mac because of violation action=autoreg");

            require pf::node;
            if (!pf::node::node_register($mac, $autoreg_node_defaults{'pid'}, %autoreg_node_defaults)) {
                $logger->error("auto-registration of node $mac failed");
                return 0;
            }
        } else {
            $logger->info("autoreg action defined for violation $vid, but won't do it: custom config said not to");
        }
    } else {
        $logger->warn("autoreg action defined for violation $vid, but registration disabled");
    }
}

sub action_close {
   my ($mac, $vid) = @_;
   my $logger = Log::Log4perl::get_logger('pf::action');

   #We need to fetch which violation id to close
   my $class = class_view($vid);

   $logger->info("VID to close: $class->{'vclose'}");

   if (defined($class->{'vclose'})) {
     my $result = violation_force_close($mac,$class->{'vclose'});
        
     # If close is a success, reevaluate the Access for the node
     if ($result) {
         pf::enforcement::reevaluate_access( $mac, "manage_vclose" );
     } else {
        $logger->warn("No open violation was found for $mac and vid $class->{'vclose'}, won't do anything");
     }
   } else {
       $logger->warn("close action defined for violation $vid, but cannot tell which violation to close");
   }
}

=head1 AUTHOR

Inverse inc. <info@inverse.ca>

Minor parts of this file may have been contributed. See CREDITS.

=head1 COPYRIGHT

Copyright (C) 2005-2013 Inverse inc.

Copyright (C) 2005 Kevin Amorin

Copyright (C) 2005 David LaPorte

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
