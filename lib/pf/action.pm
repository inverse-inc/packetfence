package pf::action;

=head1 NAME

pf::action - module to handle security_event actions

=cut

=head1 DESCRIPTION

pf::action contains the functions necessary to manage all the different
actions (email, log, trap, ...) triggered when a security_event is created,
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
use pf::security_event_config;
use pf::config qw(access_duration);

use pf::provisioner;
use pf::constants;
use pf::dal::action;
use pf::error qw(is_error is_success);

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

Readonly::Array our @SECURITY_EVENT_ACTIONS =>
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
use pf::class qw(class_view);
use pf::security_event qw(security_event_force_close);
use pf::Connection::ProfileFactory;
use pf::constants::scan qw($POST_SCAN_SECURITY_EVENT_ID $PRE_SCAN_SECURITY_EVENT_ID);
use pf::file_paths qw($security_event_log);

our $logger = get_logger();

sub action_exist {
    my ($security_event_id, $action) = @_;
    my ($status, $iter) = pf::dal::action->search(
        -where => {
            security_event_id => $security_event_id,
            action => $action
        }, 
        -columns => [\1]
    );
    if (is_error($status)) {
        return (0);
    }
    my $items = $iter->all(undef);
    return (scalar @$items);
}

sub action_add {
    my ($security_event_id, $action) = @_;
    my ($status, $item) = pf::dal::action->find_or_create({security_event_id => $security_event_id, action => $action});
    if (is_error($status)) {
        return (0);
    }
    if ($status == $STATUS::CREATED) {
        return (1);
    }
    return (2);
}

sub action_view {
    my ($security_event_id, $action) = @_;
    my ($status, $item) = pf::dal::action->find({security_event_id => $security_event_id, action => $action});
    if (is_error($status)) {
        return (0);
    }
    return ($item->to_hash());
}

sub action_view_all {
    my ($security_event_id) = @_;
    my ($status, $iter) = pf::dal::action->search(
        -where => {
            security_event_id => $security_event_id
        }
    );
    if (is_error($status)) {
        return;
    }
    my $items = $iter->all(undef);
    return @$items;
}

sub action_delete {
    my ($security_event_id, $action) = @_;
    my $status = pf::dal::action->remove_by_id({security_event_id => $security_event_id, action => $action});
    if (is_error($status)) {
        return (0);
    }
    $logger->debug("action $action deleted from class $security_event_id");
    return (1);
}

sub action_delete_all {
    my ($security_event_id) = @_;
    my ($status, $rows) = pf::dal::action->remove_items(
        -where => {
            security_event_id => $security_event_id
        }
    );
    if (is_error($status)) {
        return (undef);
    }
    $logger->debug("all actions ($rows) for class $security_event_id deleted");
    return (1);
}

# TODO what is that? Isn't it dangerous?
sub action_api {
    my ($mac, $security_event_id) = @_;
    my $logger = get_logger();
    my $class_info = class_view($security_event_id);
    my @params = split(' ', $class_info->{'external_command'});
    my $return;
    my $node_info = node_view($mac);
    my $ip = pf::ip4log::mac2ip($mac) || 0;
    $node_info = {%$node_info, 'last_ip' => $ip};
    # Replace parameters in the cli by the real one (for example: $last_ip will be changed to the value of $node_info->{last_ip})
    foreach my $param (@params) {
        $param =~ s/\$security_event_id/$security_event_id/ge;
        $param =~ s/\$(.*)/$node_info->{$1}/ge;
        $return .= $param." ";
    }
    $logger->warn($return);

    my $cmd = "sudo $return 2>&1";

    my @lines  = pf_run($cmd);
    return;
}

our %ACTIONS = (
    $REEVALUATE_ACCESS    => \&action_reevaluate_access,
    $EMAIL_ADMIN          => \&action_email_admin,
    $EMAIL_USER           => \&action_email_user,
    $LOG                  => \&action_log,
    $EXTERNAL             => \&action_api,
    $CLOSE                => \&action_close,
    $ROLE                 => \&action_role,
    $UNREG                => \&action_unreg,
    $ENFORCE_PROVISIONING => \&action_enforce_provisioning,
    $AUTOREG              => \&action_autoregister,
);

sub action_execute {
    my ($mac, $security_event_id, $notes) = @_;
    my $logger = get_logger();
    my $leave_open = 0;
    my @actions = action_view_all($security_event_id);
    # Sort the actions in reverse order in order to always finish with the autoreg action
    @actions = sort { $b->{action} cmp $a->{action} } @actions;
    foreach my $row (@actions) {
        my $action = lc $row->{'action'};
        $logger->info("executing action '$action' on class $security_event_id");
        if (!exists $ACTIONS{$action}) {
            $logger->error( "unknown action '$action' for class $security_event_id", 1 );
            next;
        }
        if ($action eq $REEVALUATE_ACCESS) {
            $leave_open = 1;
        }
        $ACTIONS{$action}->($mac, $security_event_id, $notes);
    }
    if (!$leave_open && !($security_event_id eq $POST_SCAN_SECURITY_EVENT_ID || $security_event_id eq $PRE_SCAN_SECURITY_EVENT_ID)) {
        $logger->info("this is a non-reevaluate-access security_event, closing security_event entry now");
        require pf::security_event;
        pf::security_event::security_event_force_close( $mac, $security_event_id );
    }
    return (1);
}

sub action_enforce_provisioning {
    my ($mac, $security_event_id, $notes) = @_;
    my $logger = get_logger();
    my $profile = pf::Connection::ProfileFactory->instantiate($mac);
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
    my ($mac, $security_event_id) = @_;
    my %info;

    my $class_info = class_view($security_event_id);
    $info{'category'} = $class_info->{'target_category'};

    node_modify($mac, %info);
}

sub action_unreg {
    my ($mac, $security_event_id) = @_;

    node_deregister($mac);
}

sub action_email_admin {
    my ($mac, $security_event_id, $notes) = @_;
    my %message;

    require pf::lookup::node;
    my $class_info  = class_view($security_event_id);
    my $description = $class_info->{'description'};

    $message{'subject'} = "$description detection on $mac";
    $message{'message'} = "Detect  : $description\n";
    $message{'message'} .= "$notes\n";
    $message{'message'} .= pf::lookup::node::lookup_node($mac);

    pfmailer(%message);
}

sub action_email_user {
    my ($mac, $security_event_id, $notes) = @_;
    my $node_info = node_attributes($mac);
    my $person    = person_view( $node_info->{pid} );

    if (defined($person->{email}) && $person->{email}) {
        my %message;
        require pf::lookup::node;
        my $class_info  = class_view($security_event_id);
        my $description = $class_info->{'description'};

        my $additionnal_message = join('<br/>', split('\n', $pf::security_event_config::SecurityEvent_Config{$security_event_id}{user_mail_message}));
        my $to = $person->{email};
        pf::config::util::send_email(
            'security_event-triggered',
            $to,
            "$description detection on $mac",
            {
                description         => $description,
                hostname            => $node_info->{computername},
                os                  => $node_info->{device_type},
                mac                 => $mac,
                additionnal_message => $additionnal_message,
            }
        );
    }
    else {
        get_logger->warn("Cannot send security_event email for $security_event_id as node we don't have the e-mail address of $node_info->{pid}");
    }
}

sub action_log {
    my ($mac, $security_event_id) = @_;
    my $logger = get_logger();
    require pf::ip4log;
    my $ip = pf::ip4log::mac2ip($mac) || 0;

    my $class_info  = class_view($security_event_id);
    my $description = $class_info->{'description'};

    #my $security_event_info = security_event_view($mac, $security_event_id);
    #my $date = $security_event_info->{'start_date'};
    my $date = mysql_date();

    my $logfile = $security_event_log;
    $logger->info(
        "$logfile $date: $description ($security_event_id) detected on node $mac ($ip)");
    my $log_fh;
    open( $log_fh, '>>', "$logfile" )
        || $logger->logcroak("Unable to open $logfile for append: $!");
    print {$log_fh}
        "$date: $description ($security_event_id) detected on node $mac ($ip)\n";
    close($log_fh);
}

sub action_reevaluate_access {
    my ($mac, $security_event_id) = @_;
    pf::enforcement::reevaluate_access($mac, "manage_vopen");
}

sub action_autoregister {
    my ($mac, $security_event_id) = @_;
    my $logger = get_logger();
    my $unregdate = access_duration($pf::security_event_config::SecurityEvent_Config{$security_event_id}{access_duration});
    my ( $status, $status_msg );

    if(pf::node::is_node_registered($mac)){
        $logger->debug("Calling autoreg on already registered node. Doing nothing.");
    }
    else {
        require pf::role::custom;
        ( $status, $status_msg ) = pf::node::node_register($mac, "default", "unregdate"=>$unregdate);
        if(!$status){
            $logger->error("auto-registration of node $mac failed");
            return;
        }

        require pf::enforcement;
        pf::enforcement::reevaluate_access($mac, 'manage_register');
    }
}

sub action_close {
   my ($mac, $security_event_id) = @_;
   #We need to fetch which security_event id to close
   my $class = class_view($security_event_id);

   $logger->info("SECURITY_EVENT_ID to close: $class->{'vclose'}");

   if (defined($class->{'vclose'})) {
     my $result = security_event_force_close($mac,$class->{'vclose'});

     # If close is a success, reevaluate the Access for the node
     if ($result) {
         pf::enforcement::reevaluate_access( $mac, "manage_vclose" );
     } else {
        $logger->warn("No open security_event was found for $mac and security_event_id $class->{'vclose'}, won't do anything");
     }
   } else {
       $logger->warn("close action defined for security_event $security_event_id, but cannot tell which security_event to close");
   }
}

=head1 AUTHOR

Inverse inc. <info@inverse.ca>

Minor parts of this file may have been contributed. See CREDITS.

=head1 COPYRIGHT

Copyright (C) 2005-2019 Inverse inc.

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
