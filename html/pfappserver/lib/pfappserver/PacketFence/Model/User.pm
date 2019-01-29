package pfappserver::PacketFence::Model::User;

=head1 NAME

pfappserver::PacketFence::Model::User - Catalyst Model

=head1 DESCRIPTION

Catalyst Model.

=cut

use strict;
use warnings;

use Moose;
use namespace::autoclean;
use Date::Parse;
use POSIX;
use Text::CSV;
use List::MoreUtils qw(any none);

use pf::config qw(%Config);
use pf::Authentication::constants;
use pf::password;
use pf::error qw(is_error is_success);
use pf::person;
use pf::log;
use pf::node;
use pf::security_event;
use pf::enforcement qw(reevaluate_access);
use pf::util;
use pf::config::util;
use pf::web::guest;
use pf::constants;
use pf::authentication;
use pf::sms_carrier;

=head2 field_names

=cut

sub field_names {
    return [qw(pid firstname lastname email telephone nodes login_remaining) ];
}

=head2 read

=cut

sub read {
    my ($self, $c, $pids) = @_;

    my @users;

    # Fetch user information
    foreach my $pid (@$pids) {
        my $user = person_view($pid);
        if ($user && $user->{pid}) {
            if ($user->{valid_from}) {
                # Formulate activation date
                $user->{valid_from} =~ s/ \d{2}:\d{2}:\d{2}$//;
                $user->{txt_valid_from} = $c->loc("This username and password will be valid starting [_1].",
                                                  $user->{valid_from});
            }
            if ($user->{expiration}) {
                # Formulate expiration date
                $user->{expiration} =~ s/ \d{2}:\d{2}:\d{2}$//;
                $user->{txt_expiration} = $c->loc("Registration must happen before [_1].",
                                                  $user->{expiration});
            }
            if ($user->{access_duration}) {
                # Formulate access duration
                my ($singular, $plural, $value) = get_translatable_time($user->{'access_duration'});
                $user->{duration} = "$value " . $c->loc(($value > 1)?$plural:$singular);
                $user->{txt_duration} = $c->loc("Once authenticated the access will be valid for [_1] [_2].",
                                                $value,
                                                $c->loc(($value > 1)?$plural:$singular));
            }
            if ($user->{unregdate}) {
                # Formulate unregdate
                $user->{unregdate} = '' if $user->{unregdate} eq $ZERO_DATE;
                $user->{unregdate} =~ s/ 00:00:00$//;
            }
            $self->_make_actions($user);
            push(@users, $user);
        }
    }

    if (scalar @users > 0) {
        my @sorted_users = sort { $a->{pid} cmp $b->{pid} } @users;
        return ($STATUS::OK, \@sorted_users);
    }
    else {
        return ($STATUS::NOT_FOUND, "Item(s) not found");
    }
}

=head2 _make_actions

=cut

sub _make_actions {
    my ($self, $user) = @_;

    my %FIELD_TO_ACTION = (
        'can_sponsor'     => $Actions::MARK_AS_SPONSOR,
        'access_level'    => $Actions::SET_ACCESS_LEVEL,
        'tenant_id'       => $Actions::SET_TENANT_ID,
        'category'        => $Actions::SET_ROLE,
        'unregdate'       => $Actions::SET_UNREG_DATE,
        'access_duration' => $Actions::SET_ACCESS_DURATION,
        'time_balance'      => $Actions::SET_TIME_BALANCE,
        'bandwidth_balance' => $Actions::SET_ACCESS_DURATION,
    );

    my @actions = map +{ type => $FIELD_TO_ACTION{$_}, value => $user->{$_} }, grep { $user->{$_} } keys %FIELD_TO_ACTION;
    $user->{actions} = \@actions;
}

=head2 countAll

=cut

sub countAll {
    my ( $self, %params ) = @_;

    my $logger = get_logger();
    my ($status, $status_msg);

    my $count;
    eval {
        my @result = person_count_all(%params);
        $count = pop @result;
    };
    if ($@) {
        $status_msg = "Can't count users from database.";
        $logger->error($status_msg);
        return ($STATUS::INTERNAL_SERVER_ERROR, $status_msg);
    }

    return ($STATUS::OK, $count->{nb});
}

=head2 search

=cut

sub search {
    my ( $self, %params ) = @_;

    my $logger = get_logger();
    my ($status, $status_msg);

    my @users;
    eval {
        @users = person_view_all(%params);
    };
    if ($@) {
        $status_msg = "Can't fetch users from database.";
        $logger->error($status_msg);
        return ($STATUS::INTERNAL_SERVER_ERROR, $status_msg);
    }

    return ($STATUS::OK, \@users);
}

=head2 nodes

Return the nodes associated to the person ID.

=cut

sub nodes {
    my ( $self, $pid ) = @_;

    my $logger = get_logger();
    my ($status, $status_msg);

    my @nodes;
    eval {
        @nodes = person_nodes($pid);
    };
    if ($@) {
        $status_msg = "Can't fetch nodes from database.";
        $logger->error($status_msg);
        return ($STATUS::INTERNAL_SERVER_ERROR, $status_msg);
    }

    return ($STATUS::OK, \@nodes);
}

=head2 security_events

Return the security_events associated to the person ID.

=cut

sub security_events {
    my ($self, $pid) = @_;

    my $logger = get_logger();
    my ($status, $status_msg);

    my @security_events;
    eval {
        @security_events = person_security_events($pid);
        map { $_->{release_date} = '' if ($_->{release_date} eq '0000-00-00 00:00:00') } @security_events;
    };
    if ($@) {
        $status_msg = "Can't fetch security_events from database.";
        $logger->error($status_msg);
        return ($STATUS::INTERNAL_SERVER_ERROR, $status_msg);
    }

    return ($STATUS::OK, \@security_events);
}

=head2 update

=cut

sub update {
    my ($self, $pid, $user_ref, $user) = @_;
    my $logger = get_logger();
    unless ($self->_userRoleAllowedForUser($user_ref, $user)) {
        return ($STATUS::INTERNAL_SERVER_ERROR, 'Do not have permission to add the ALL role to a user');
    }

    my ($status, $status_msg) = ($STATUS::OK);
    my $actions = delete $user_ref->{actions};

    unless (person_modify($pid, %{$user_ref})) {
        $status = $STATUS::INTERNAL_SERVER_ERROR;
        $status_msg = 'An error occurred while updating the user.';
    }
    elsif ($actions) {
        # Update the actions and the registration window
        push(@$actions, { type => 'valid_from', value => $user_ref->{valid_from} });
        push(@$actions, { type => 'expiration', value => $user_ref->{expiration} });
        ($status, $status_msg) = $self->update_actions($pid, $actions);
    }

    return ($status, $status_msg);
}

=head2 update_actions

=cut

sub update_actions {
    my ($self, $pid, $actions) = @_;

    my $logger = get_logger();
    my ($status, $status_msg) = ($STATUS::OK);
    my $tp = pf::password::view($pid);
    # Only update the actions if the user has an entry in password
    unless (!$tp || pf::password::modify_actions($tp, $actions)) {
        $status = $STATUS::INTERNAL_SERVER_ERROR;
        $status_msg = 'An error occurred while updating the user actions.';
    }

    return ($status, $status_msg);
}

=head2 mail

=cut

sub mail {
    my ($self, $c, $pids) = @_;

    my $logger = get_logger();
    my ($status, $status_msg) = ($STATUS::OK);
    my @users;

    # we get the created users from the session so we have a copy of the cleartext password
    my %users_passwords_by_pid = map { $_->{'pid'}, $_ } @{ $c->session->{'users_passwords'} };
    # Fetch user information
    ($status, $status_msg) = $self->read($c, $pids);
    if (is_success($status)) {
        my $lang = $Config{advanced}{language};
        my $user_locale = clean_locale(setlocale(POSIX::LC_MESSAGES));
        setlocale(POSIX::LC_MESSAGES, "$lang.utf8");
        foreach my $user (@$status_msg) {
            # we overwrite the password found in the database with the one in the session for the same user
            my $pid = $user->{'pid'};
            if ( exists $users_passwords_by_pid{$pid} ) {
                $user->{'password'} = $users_passwords_by_pid{$pid}->{'password'};
            }

            eval {
                if (length $user->{email} > 0) {
                    $user->{username} = $user->{pid};
                    pf::web::guest::send_template_email($pf::web::guest::TEMPLATE_EMAIL_GUEST_ADMIN_PREREGISTRATION,
                                                        $c->loc("[_1]: Guest Network Access Information", $Config{'general'}{'domain'}),
                                                        $user);
                    push(@users, $user);
                    $logger->info("Sent credentials to ".$user->{email}." (".$user->{pid}.")");
                }
            };
            if ($@) {
                $logger->error($@);
            }
        }
        setlocale(POSIX::LC_MESSAGES, $user_locale);
    }

    if (@users) {
        $status_msg = \@users;
    }
    else {
        $status = $STATUS::INTERNAL_SERVER_ERROR;
        $status_msg = 'Unexpected error. See server-side logs for details.';
    }

    return ($status, $status_msg);
}

=head2 sms

=cut

sub sms {
    my ($self, $c, $pids) = @_;
    my $logger = get_logger();
    my ($status, $status_msg) = ($STATUS::OK);
    my @users;

    # we get the created users from the session so we have a copy of the cleartext password
    my %users_passwords_by_pid = map { $_->{'pid'}, $_ } @{ $c->session->{'users_passwords'} };
    my $sms_source = getAuthenticationSource($Config{advanced}{source_to_send_sms_when_creating_users});
    unless ($sms_source) {
        return ($STATUS::INTERNAL_SERVER_ERROR, 'Send SMS is disabled or misconfigured');
    }
    my $sms_carrier_id = $c->request->param('sms_carrier');
    my $sms_carrier = sms_carrier_view($sms_carrier_id) if defined $sms_carrier_id;
    # Fetch user information
    ($status, $status_msg) = $self->read($c, $pids);
    if (!is_success($status)) {
        return ($status, $status_msg);
    }
    my $temp = $status_msg;
    $status_msg = \@users;
    foreach my $user (@$temp) {
        my $telephone = $user->{telephone};
        my $pid = $user->{'pid'};
        unless (defined $telephone && length $telephone > 0) {
            $logger->warn("Trying to send an sms to $pid he has no phone");
            next;
        }
        # we overwrite the password found in the database with the one in the session for the same user
        if ( exists $users_passwords_by_pid{$pid} ) {
            $user->{'password'} = $users_passwords_by_pid{$pid}->{'password'};
        }

        eval {
            $user->{username} = $pid;
            $sms_source->sendSMS({ to => $telephone, message => $self->sms_message($user), activation => $sms_carrier});
            push(@users, $user);
            $logger->info("Sent credentials to $telephone ($pid)");
        };
        if ($@) {
            $status = $STATUS::INTERNAL_SERVER_ERROR;
            $status_msg = 'Unexpected error. See server-side logs for details.';
            $logger->error($@);
        }
    }

    if (@users) {
        $status_msg = \@users;
        $status = $STATUS::OK;
    }

    return ($status, $status_msg);
}

=head2 sms_message

Create the sms_message

=cut

sub sms_message {
    my ($self, $user) = @_;
    my $message = "Credentials to our captive portal\nUsername: $user->{pid}\nPassword: $user->{'password'}\n";
    return $message;
}

=head2 unassignNodes

Unassigns the users nodes so he can be safely deleted

=cut

sub unassignNodes {
    my ($self, $pid) = @_;
    foreach my $node (person_nodes($pid)) {
        unless(node_modify($node->{mac}, pid => $default_pid)) {
            return ($STATUS::INTERNAL_SERVER_ERROR, "Cannot reset owner of ".$node->{mac});
        }
    }
    return ($STATUS::OK, "The nodes of $pid were successfully assigned to the default PID.");
}

=head2 delete

=cut

sub delete {
    my ($self, $pid) = @_;

    my $logger = get_logger();
    my ($status, $status_msg) = ($STATUS::OK, 'The user was successfully deleted.');

    eval {
        my $result = person_delete($pid); # entry from password will be automatically deleted
        unless ($result) {
            ($status, $status_msg) = ($STATUS::INTERNAL_SERVER_ERROR, "The user still owns nodes and can't be deleted.");
        }
    };
    if ($@) {
        $logger->error($@);
        $status = $STATUS::INTERNAL_SERVER_ERROR;
        $status_msg = "Can't delete person from the database.";
    }

    $logger->info("$pid: $status_msg");
    return ($status, $status_msg);
}

=head2 createSingle

pf::web::guest::preregister

=cut

sub createSingle {
    my ($self, $data, $user) = @_;

    my $logger = get_logger();
    my ($status, $result) = ($STATUS::CREATED);
    my $pid = $data->{pid};
    my @users = ();

    unless ($self->_userRoleAllowedForUser($data, $user)) {
        return ($STATUS::INTERNAL_SERVER_ERROR, 'Do not have permission to add the ALL role to a user');
    }

    # Check if PID already exists (only if not configured to overwrite existing PIDs)
    if ( !$data->{'pid_overwrite'} && pf::person::person_exist($pid) ) {
        return ( $STATUS::INTERNAL_SERVER_ERROR, "User '$pid' already exists" );
    }

    # Adding person
    $result = person_modify($pid,
                            (
                             'firstname' => $data->{firstname},
                             'lastname' => $data->{lastname},
                             'email' => $data->{email},
                             'telephone' => $data->{telephone},
                             'company' => $data->{company},
                             'address' => $data->{address},
                             'notes' => $data->{notes},
                             'sponsor' => $user,
                            )
                           );
    if ($result) {
        $logger->info("Created user account $pid. Sponsored by $user");
        # Add the registration window to the actions
        push(@{$data->{actions}}, { type => 'valid_from', value => $data->{valid_from} });
        push(@{$data->{actions}}, { type => 'expiration', value => $data->{expiration} });
        $result = pf::password::generate($pid, $data->{actions}, $data->{password}, $data->{login_remaining});
        if ($result) {
            push(@users, { pid => $pid, email => $data->{email}, password => $result });
        }
    }

    unless ($result) {
        return ($STATUS::INTERNAL_SERVER_ERROR, 'Unexpected error. See server-side logs for details.');
    }

    return ($status, \@users);
}

=head2 _userRoleAllowedForUser

    ensure the only uses with the all role can give another user the all role

=cut

sub _userRoleAllowedForUser {
    my ($self, $data, $user) = @_;
    #If the user has the ALL role then they are good
    return 1 if any { 'ALL' eq $_ } $user->roles;
    #User does not have the role of ALL then it cannot create a user with the same role
    return none { __doesActionHaveAllAccessLevel($_) } @{$data->{actions} || []};
}

=head2 __doesActionHaveAllAccessLevel

   does the action have the All role

=cut

sub __doesActionHaveAllAccessLevel {
    my ($action) = @_;
    local $_;
    return $action->{type} eq 'set_access_level'
      && any {$_ eq 'ALL'} split(/\s*,\s*/, $action->{value});
}

=head2 createMultiple

pf::web::guest::preregister_multiple

=cut

sub createMultiple {
    my ($self, $data, $user) = @_;

    my $logger = get_logger();
    unless ($self->_userRoleAllowedForUser($data, $user)) {
        return ($STATUS::INTERNAL_SERVER_ERROR, 'Do not have permission to add the ALL role to a user');
    }
    my ($status, $result) = ($STATUS::CREATED);
    my $pid;
    my $prefix = $data->{prefix};
    my $quantity = int($data->{quantity});
    my @users = ();
    my $count = 0;

    my @skipped = ();
    for (my $i = 1; $i <= $quantity; $i++) {
        $pid = "$prefix$i";

        # Check if PID already exists (only if not configured to overwrite existing PIDs)
        if ( !$data->{'pid_overwrite'} && pf::person::person_exist($pid) ) {
            $logger->warn("Tried to create existing user '$pid' while creating multiple. Skipping");
            push @skipped, $pid;
            # Incrementing quantity (number of user to create) since we were unable to create the current one
            $quantity++;
            next;
        }

        # Create/modify person
        $result = person_modify($pid,
                                (
                                 'firstname' => $data->{firstname},
                                 'lastname' => $data->{lastname},
                                 'email' => $data->{email},
                                 'telephone' => $data->{phone},
                                 'company' => $data->{company},
                                 'address' => $data->{address},
                                 'notes' => $data->{notes},
                                 'sponsor' => $user),
                               );
        if ($result) {
            # Create/update password
            # Add the registration window to the actions
            push(@{$data->{actions}}, { type => 'valid_from', value => $data->{valid_from} });
            push(@{$data->{actions}}, { type => 'expiration', value => $data->{expiration} });
            $result = pf::password::generate($pid, $data->{actions}, undef, $data->{login_remaining});
            if ($result) {
                push(@users, { pid => $pid, email => $data->{email}, password => $result });
                $count++;
            }
        }
    }
    $logger->info("Created $count user accounts: $prefix"."[1-$quantity]. Sponsored by $user");

    if ($count == 0) {
        return ($STATUS::INTERNAL_SERVER_ERROR, 'Unexpected error. See server-side logs for details.');
    }

    return ($status, \@users, \@skipped);
}

=head2 import

pf::web::guest::import_csv

=cut

sub importCSV {
    my ($self, $data, $user) = @_;

    my $logger = get_logger();
    unless ($self->_userRoleAllowedForUser($data, $user)) {
        return ($STATUS::INTERNAL_SERVER_ERROR, 'Do not have permission to add the ALL role to a user');
    }
    my ($status, $message);
    my @users = ();
    my $filename = $data->{users_file}->filename;
    my $tmpfilename = $data->{users_file}->tempname;
    my $delimiter = $data->{delimiter};

    $logger->debug("CSV file import users from $tmpfilename ($filename, \"$delimiter\")");

    # Build hash table for columns order
    my $count = 0;
    my $skipped = 0;
    my %index = ();
    foreach my $column (@{$data->{columns}}) {
        if ($column->{enabled} || $column->{name} eq 'c_username' || $column->{name} eq 'c_password') {
            # Add checked columns and mandatory columns
            $index{$column->{name}} = $count;
            $count++;
        }
    }

    # Map delimiter to its actual character
    if ($delimiter eq 'comma') {
        $delimiter = ',';
    } elsif ($delimiter eq 'semicolon') {
        $delimiter = ';';
    } elsif ($delimiter eq 'colon') {
        $delimiter = ':';
    } elsif ($delimiter eq 'tab') {
        $delimiter = "\t";
    }

    # Read CSV file
    $count = 0;
    if (open (my $import_fh, "<", $tmpfilename)) {
        my $csv = Text::CSV->new({ binary => 1, sep_char => $delimiter });
        while (my $row = $csv->getline($import_fh)) {
            my @skipped = ();
            my $pid = $row->[$index{'c_username'}];
            if ($pid !~ /$pf::person::PID_RE/) {
                $skipped++;
                next;
            }

            # Check if PID already exists (only if not configured to overwrite existing PIDs)
            if ( !$data->{'pid_overwrite'} && pf::person::person_exist($pid) ) {
                $logger->warn("Tried to import an existing user with PID '$pid' from CSV file. Skipping it");
                $skipped++;
                push @skipped, $pid;
                next;
            }
                
            # Create/modify person
            my %person =
              (
               'firstname' => $index{'c_firstname'} ? $row->[$index{'c_firstname'}] : undef,
               'lastname'  => $index{'c_lastname'}  ? $row->[$index{'c_lastname'}]  : undef,
               'email'     => $index{'c_email'}     ? $row->[$index{'c_email'}]     : undef,
               'telephone' => $index{'c_phone'}     ? $row->[$index{'c_phone'}]     : undef,
               'company'   => $index{'c_company'}   ? $row->[$index{'c_company'}]   : undef,
               'address'   => $index{'c_address'}   ? $row->[$index{'c_address'}]   : undef,
               'notes'     => $index{'c_note'}      ? $row->[$index{'c_note'}]      : undef,
               'sponsor'   => $user,
              );
            if ($person{'email'} && $person{'email'} !~ /^[A-z0-9_.-]+@[A-z0-9_-]+(\.[A-z0-9_-]+)*\.[A-z]{2,6}$/) {
                $skipped++;
                next;
            }
            my $result = person_modify($pid, %person);
            if ($result) {
                # Create/update password
                # The registration window is add to the actions
                push(@{$data->{actions}}, { type => 'valid_from', value => $data->{valid_from} });
                push(@{$data->{actions}}, { type => 'expiration', value => $data->{expiration} });
                $result = pf::password::generate($pid, $data->{actions}, $row->[$index{'c_password'}]);
                push(@users, { pid => $pid, email => $person{email}, password => $result });
                $count++;
            }
        }
        unless ($csv->eof) {
            $logger->warn("Problem with CSV file importation: " . $csv->error_diag());
            ($status, $message) = ($STATUS::INTERNAL_SERVER_ERROR, ["Problem with importation: [_1]" , $csv->error_diag()]);
        }
        else {
            my @sorted_users = sort { $a->{pid} cmp $b->{pid} } @users;
            ($status, $message) = ($STATUS::CREATED, \@sorted_users);
        }
        close $import_fh;
    }
    else {
        $logger->warn("Can't open CSV file $filename: $@");
        ($status, $message) = ($STATUS::INTERNAL_SERVER_ERROR, "Can't read CSV file.");
    }

    $logger->info("CSV file ($filename) import $count users, skip $skipped users. Sponsored by $user");

    return ($status, $message);
}

=head2 bulkRegister

=cut

sub bulkRegister {
    my ($self,@ids) = @_;
    my $count = 0;
    my ($status,$status_msg);
    foreach my $node (map {person_nodes($_)} @ids  ) {
        if($node->{status} eq $pf::node::STATUS_UNREGISTERED) {
            my $mac = $node->{mac};
            ( $status, $status_msg ) = pf::node::node_register($mac, $node->{pid}, %{$node});
            if( $status ) {
                reevaluate_access($mac, "node_modify");
                $count++;
            }
        }
    }
    return ($STATUS::OK, ["[_1] node(s) were registered.",$count]);
}

=head2 bulkDeregister

=cut

sub bulkDeregister {
    my ($self,@ids) = @_;
    my $count = 0;
    foreach my $node (map {person_nodes($_)} @ids  ) {
        if($node->{status} eq $pf::node::STATUS_REGISTERED) {
            my $mac = $node->{mac};
            if(node_deregister($mac, $node->{pid}, %{$node})) {
                reevaluate_access($mac, "node_modify");
                $count++;
            }
        }
    }
    return ($STATUS::OK, ["[_1] node(s) were deregistered.",$count]);
}

=head2 bulkApplyRole

=cut

sub bulkApplyRole {
    my ($self,$role,@ids) = @_;
    my $count = 0;
    foreach my $node (map {person_nodes($_)} @ids  ) {
        $node->{category_id} = $role;
        $count++ if node_modify($node->{mac}, %{$node});
    }
    return ($STATUS::OK, ["Role was changed for [_1] node(s)",$count]);
}

=head2 bulkApplySecurityEvent

=cut

sub bulkApplySecurityEvent {
    my ($self, $security_event_id, @ids) = @_;
    my $count = 0;
    my $logger = get_logger();
    foreach my $mac (map {$_->{mac}} map {person_nodes($_)} @ids  ) {
        my ($last_id) = security_event_add( $mac, $security_event_id);
        $count++ if $last_id > 0;;
    }
    return ($STATUS::OK, ["[_1] security_event(s) were opened.",$count]);
}

=head2 closeSecurityEvents

=cut

sub bulkCloseSecurityEvents {
    my ($self, @ids) = @_;
    my $count = 0;
    foreach my $mac (map {$_->{mac}} map {person_nodes($_)} @ids  ) {
        foreach my $security_event (security_event_view_open_desc($mac)) {
            if (security_event_force_close( $mac, $security_event->{security_event_id})) {
                pf::enforcement::reevaluate_access($mac, 'manage_vclose');
                $count++;
            }
        }
    }
    return ($STATUS::OK, ["[_1] security_event(s) were closed.",$count]);
}

=head2 bulkDelete

=cut

sub bulkDelete {
    my ($self, @ids) = @_;
    my $count = 0;
    foreach my $pid ( @ids  ) {
        if(is_success($self->unassignNodes($pid)) && is_success($self->delete($pid))) {
            $count++;
        }
    }
    return ($STATUS::OK, ["[_1] users were deleted.",$count]);
}

=head1 COPYRIGHT

Copyright (C) 2005-2018 Inverse inc.

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

__PACKAGE__->meta->make_immutable unless $ENV{"PF_SKIP_MAKE_IMMUTABLE"};

1;
