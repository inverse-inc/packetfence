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
use pf::log;
use Readonly;
use pf::node;
use pf::person;
use pf::util;
use pf::violation_config;
use pf::provisioner;
use pf::constants;

use constant ACTION => 'action';

# Action types constants
#FIXME port all hard-coded strings to these constants
Readonly::Scalar our $AUTOREG => 'autoreg';
Readonly::Scalar our $UNREG => 'unreg';
Readonly::Scalar our $REEVALUATE_ACCESS => 'reevaluate_access';
Readonly::Scalar our $EMAIL_USER => 'email_user';
Readonly::Scalar our $EMAIL_ADMIN => 'email_admin';
Readonly::Scalar our $LOG => 'log';
Readonly::Scalar our $EXTERNAL => 'external';
Readonly::Scalar our $CLOSE => 'close';
Readonly::Scalar our $ROLE => 'role';
Readonly::Scalar our $ENFORCE_PROVISIONING => 'enforce_provisioning';

Readonly::Array our @VIOLATION_ACTIONS =>
  (
   $AUTOREG,
   $UNREG,
   $EMAIL_USER,
   $EMAIL_ADMIN,
   $REEVALUATE_ACCESS,
   $LOG,
   $EXTERNAL,
   $CLOSE,
   $ROLE,
   $ENFORCE_PROVISIONING,
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

use pf::config qw(
    %Config
    $fqdn
);
use pf::db;
use pf::util;
use pf::config::util;
use pf::class qw(class_view class_view_actions);
use pf::violation qw(violation_force_close);
use pf::Portal::ProfileFactory;
use pf::constants::scan qw($POST_SCAN_VID $PRE_SCAN_VID);

# The next two variables and the _prepare sub are required for database handling magic (see pf::db)
our $action_db_prepared = 0;
# in this hash reference we hold the database statements. We pass it to the query handler and he will repopulate
# the hash if required
our $action_statements = {};

sub action_db_prepare {
    my $logger = get_logger();
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
    my $logger = get_logger();
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
    my $logger = get_logger();
    db_query_execute(ACTION, $action_statements, 'action_delete_sql', $vid, $action) || return (0);
    $logger->debug("action $action deleted from class $vid");

    return (1);
}

sub action_delete_all {
    my ($vid) = @_;
    my $logger = get_logger();
    db_query_execute(ACTION, $action_statements, 'action_delete_all_sql', $vid) || return (0);
    $logger->debug("all actions for class $vid deleted");

    return (1);
}

# TODO what is that? Isn't it dangerous?
sub action_api {
    my ($mac, $vid) = @_;
    my $logger = get_logger();
    my $class_info = class_view($vid);
    my @params = split(' ', $class_info->{'external_command'});
    my $return;
    my $node_info = node_view($mac);
    my $ip = pf::iplog::mac2ip($mac) || 0;
    $node_info = {%$node_info, 'last_ip' => $ip};
    # Replace parameters in the cli by the real one (for example: $last_ip will be changed to the value of $node_info->{last_ip})
    foreach my $param (@params) {
        $param =~ s/\$vid/$vid/ge;
        $param =~ s/\$(.*)/$node_info->{$1}/ge;
        $return .= $param." ";
    }
    $logger->warn($return);

    my $cmd = "sudo $return 2>&1";

    my @lines  = pf_run($cmd);
    return;
}

sub action_execute {
    my ($mac, $vid, $notes) = @_;
    my $logger = get_logger();
    my $leave_open = 0;
    my @actions = class_view_actions($vid);
    # Sort the actions in reverse order in order to always finish with the autoreg action
    @actions = sort { $b->{action} cmp $a->{action} } @actions;
    foreach my $row (@actions) {
        my $action = lc $row->{'action'};
        $logger->info("executing action '$action' on class $vid");
        if ( $action eq $REEVALUATE_ACCESS ) {
            $leave_open = 1;
            action_reevaluate_access( $mac, $vid );
        } elsif ( $action eq $EMAIL_ADMIN ) {
            action_email_admin( $mac, $vid, $notes );
        } elsif ( $action eq $EMAIL_USER ) {
            action_email_user( $mac, $vid, $notes );
        } elsif ( $action eq $LOG ) {
            action_log( $mac, $vid );
        } elsif ( $action eq $EXTERNAL ) {
            action_api( $mac, $vid );
        } elsif ( $action eq $CLOSE ) {
            action_close( $mac, $vid );
        } elsif ( $action eq $ROLE ) {
            action_role( $mac, $vid );
        } elsif ( $action eq $UNREG ) {
            action_unreg( $mac, $vid );
        } elsif ( $action eq $ENFORCE_PROVISIONING ) {
            action_enforce_provisioning( $mac, $vid, $notes );
        } elsif ( $action eq $AUTOREG ) {
            action_autoregister($mac, $vid);
        } else {
            $logger->error( "unknown action '$action' for class $vid", 1 );
        }
    }
    if ( !$leave_open && !( ($vid eq $POST_SCAN_VID) || ($vid eq $PRE_SCAN_VID) ) ) {
        $logger->info("this is a non-reevaluate-access violation, closing violation entry now");
        require pf::violation;
        pf::violation::violation_force_close( $mac, $vid );
    }
    return (1);
}

sub action_enforce_provisioning {
    my ($mac, $vid, $notes) = @_;
    my $logger = get_logger();
    my $profile = pf::Portal::ProfileFactory->instantiate($mac);
    if (defined(my $provisioner = $profile->findProvisioner($mac))) {
        my $result = $provisioner->authorize($mac);
        if ($result == $TRUE) {
            $logger->debug("$mac is still authorized with it's provisioner");
        }
        elsif($result == $pf::provisioner::COMMUNICATION_FAILED){
            $logger->info("Not enforcing provisioning since communication failed...");
        }
        else{
            $logger->warn("$mac is not authorized anymore with it's provisionner. Putting node as pending.");
            node_modify($mac, status => $pf::node::STATUS_PENDING);
            pf::enforcement::reevaluate_access($mac, "manage_vopen");
        }
    }
    else{
        $logger->debug("Can't find provisioner for $mac");
    }
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

sub action_email_admin {
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

sub action_email_user {
    my ($mac, $vid, $notes) = @_;
    my $node_info = node_attributes($mac);
    my $person = person_view($node_info->{pid});

    if(defined($person->{email}) && $person->{email}){
        my %message;

        require pf::lookup::node;
        my $class_info  = class_view($vid);
        my $description = $class_info->{'description'};

        my $additionnal_message = join('<br/>', split('\n',$pf::violation_config::Violation_Config{$vid}{user_mail_message}));

        pf::util::send_email(
            $Config{'alerting'}{'smtpserver'},
            $Config{'alerting'}{'fromaddr'} || 'root@' . $fqdn, $person->{email},
            "$description detection on $mac",
            "violation-triggered",
            description => $description,
            hostname => $node_info->{computername},
            os => $node_info->{device_type},
            mac => $mac,
            additionnal_message => $additionnal_message,
        );

    }
    else{
        get_logger->warn("Cannot send violation email for $vid as node we don't have the e-mail address of $node_info->{pid}");
    }
}

sub action_log {
    my ($mac, $vid) = @_;
    my $logger = get_logger();
    require pf::iplog;
    my $ip = pf::iplog::mac2ip($mac) || 0;

    my $class_info  = class_view($vid);
    my $description = $class_info->{'description'};

    #my $violation_info = violation_view($mac, $vid);
    #my $date = $violation_info->{'start_date'};
    my $date = mysql_date();

    my $logfile = untaint_chain($Config{'alerting'}{'log'});
    $logger->info(
        "$logfile $date: $description ($vid) detected on node $mac ($ip)");
    my $log_fh;
    open( $log_fh, '>>', "$logfile" )
        || $logger->logcroak("Unable to open $logfile for append: $!");
    print {$log_fh}
        "$date: $description ($vid) detected on node $mac ($ip)\n";
    close($log_fh);
}

sub action_reevaluate_access {
    my ($mac, $vid) = @_;
    pf::enforcement::reevaluate_access($mac, "manage_vopen");
}

sub action_autoregister {
    my ($mac, $vid) = @_;
    my $logger = get_logger();

    my ( $status, $status_msg );

    if(pf::node::is_node_registered($mac)){
        $logger->debug("Calling autoreg on already registered node. Doing nothing.");
    }
    else {
        require pf::role::custom;
        ( $status, $status_msg ) = pf::node::node_register($mac, "default");
        if(!$status){
            $logger->error("auto-registration of node $mac failed");
            return;
        }

        require pf::enforcement;
        pf::enforcement::reevaluate_access($mac, 'manage_register');
    }
}

sub action_close {
   my ($mac, $vid) = @_;
   my $logger = get_logger();

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

Copyright (C) 2005-2017 Inverse inc.

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
