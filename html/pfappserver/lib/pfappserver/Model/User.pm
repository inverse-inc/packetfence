package pfappserver::Model::User;

=head1 NAME

pfappserver::Model::User - Catalyst Model

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

use pf::config;
use pf::Authentication::constants;
use pf::temporary_password;
use pf::error qw(is_error is_success);
use pf::person;
use pf::util qw(get_translatable_time);


=head2 field_names

=cut

sub field_names {
    return [qw(pid firstname lastname email nodes) ];
}

=head2 read

=cut

sub read {
    my ($self, $c, $pids) = @_;

    my @users;

    # Fetch user information
    foreach my $pid (@$pids) {
        my $user = person_view($pid);
        if ($user) {
            if ($user->{valid_from}) {
                # Formulate activation date
                $user->{valid_from} =~ s/ 00:00:00$//;
                $user->{txt_valid_from} = $c->loc("This username and password will be valid starting [_1].",
                                                  $user->{valid_from});
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
                $user->{unregdate} = '' if $user->{unregdate} eq '0000-00-00 00:00:00';
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
        return ($STATUS::NOT_FOUND);
    }
}

=head2 _make_actions

=cut

sub _make_actions {
    my ( $self, $user ) = @_;
    my %FIELD_TO_ACTION = (
        'can_sponsor'  => $Actions::MARK_AS_SPONSOR,
        'access_level' => $Actions::SET_ACCESS_LEVEL ,
        'category'     => $Actions::SET_ROLE ,
        'unregdate'    => $Actions::SET_UNREG_DATE ,
        'access_duration' => $Actions::SET_ACCESS_DURATION ,
    );
    my @actions = map +{  type=>$FIELD_TO_ACTION{$_}, value => $user->{$_} }   , grep {$user->{$_}} keys %FIELD_TO_ACTION;

    $user->{actions} = \@actions;
}

=head2 countAll

=cut

sub countAll {
    my ( $self, %params ) = @_;

    my $logger = Log::Log4perl::get_logger(__PACKAGE__);
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

    my $logger = Log::Log4perl::get_logger(__PACKAGE__);
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

    my $logger = Log::Log4perl::get_logger(__PACKAGE__);
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

=head2 violations

Return the violations associated to the person ID.

=cut

sub violations {
    my ($self, $pid) = @_;

    my $logger = Log::Log4perl::get_logger(__PACKAGE__);
    my ($status, $status_msg);

    my @violations;
    eval {
        @violations = person_violations($pid);
        foreach my $violation (@violations) {
            if ($violation->{release_date} eq '0000-00-00 00:00:00') {
                $violation->{release_date} = '';
            }
        }
    };
    if ($@) {
        $status_msg = "Can't fetch violations from database.";
        $logger->error($status_msg);
        return ($STATUS::INTERNAL_SERVER_ERROR, $status_msg);
    }

    return ($STATUS::OK, \@violations);
}

=head2 update

=cut

sub update {
    my ( $self, $pid, $user_ref ) = @_;
    my $logger = Log::Log4perl::get_logger(__PACKAGE__);
    my ($status, $status_msg) = ($STATUS::OK);
    my $actions = delete $user_ref->{actions};

    unless (person_modify($pid, %{$user_ref})) {
        $status = $STATUS::INTERNAL_SERVER_ERROR;
        $status_msg = 'An error occurred while updating the user.';
    } elsif($actions) {
        ($status, $status_msg) = $self->update_actions($pid, $actions);
    }

    return ($status, $status_msg);
}

=head2 update_actions

=cut

sub update_actions {
    my ( $self, $pid, $actions ) = @_;

    my $logger = Log::Log4perl::get_logger(__PACKAGE__);
    my ($status, $status_msg) = ($STATUS::OK);
    my $tp = pf::temporary_password::view($pid);
    unless(pf::temporary_password::modify_actions($tp,$actions)) {
        $status = $STATUS::INTERNAL_SERVER_ERROR;
        $status_msg = 'An error occurred while updating the user actions.';
    }

    return ($status, $status_msg);
}

=head2 mail

=cut

sub mail {
    my ($self, $c, $pids) = @_;

    my $logger = Log::Log4perl::get_logger(__PACKAGE__);
    my ($status, $status_msg) = ($STATUS::OK);
    my @users;

    # Fetch user information
    ($status, $status_msg) = $self->read($c, $pids);
    if (is_success($status)) {
        foreach my $user (@$status_msg) {
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

=head2 delete

=cut

sub delete {
    my ($self, $pid) = @_;

    my $logger = Log::Log4perl::get_logger(__PACKAGE__);
    my ($status, $status_msg) = ($STATUS::OK, 'The user was successfully deleted.');

    eval {
        my $result = person_delete($pid); # entry from temporary_password will be automatically deleted
        unless ($result) {
            ($status, $status_msg) = ($STATUS::INTERNAL_SERVER_ERROR, "The user still has registered nodes and can't be deleted.");
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

    my $logger = Log::Log4perl::get_logger(__PACKAGE__);
    my ($status, $result) = ($STATUS::CREATED);
    my $pid = $data->{pid};
    my @users = ();

    # Adding person (using modify in case person already exists)
    $result = person_modify($pid,
                            (
                             'firstname' => $data->{firstname},
                             'lastname' => $data->{lastname},
                             'email' => $data->{email},
                             'telephone' => $data->{phone},
                             'company' => $data->{company},
                             'address' => $data->{address},
                             'notes' => $data->{notes},
                             'sponsor' => $user,
                            )
                           );
    if ($result) {
        $logger->info("Created user account $pid. Sponsored by $user");

        # We create temporary password with the expiration and a 'not valid before' value
        $result = pf::temporary_password::generate($pid,
                                                   $data->{arrival_date},
                                                   $data->{actions},
                                                   $data->{password});
        if ($result) {
            push(@users, { pid => $pid, email => $data->{email}, password => $result });
        }
    }

    unless ($result) {
        return ($STATUS::INTERNAL_SERVER_ERROR, 'Unexpected error. See server-side logs for details.');
    }

    return ($status, \@users);
}

=head2 createMultiple

pf::web::guest::preregister_multiple

=cut

sub createMultiple {
    my ($self, $data, $user) = @_;

    my $logger = Log::Log4perl::get_logger(__PACKAGE__);
    my ($status, $result) = ($STATUS::CREATED);
    my $pid;
    my $prefix = $data->{prefix};
    my $quantity = int($data->{quantity});
    my @users = ();
    my $count = 0;

    for (my $i = 1; $i <= $quantity; $i++) {
        $pid = "$prefix$i";
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
            $result = pf::temporary_password::generate($pid,
                                                       $data->{arrival_date},
                                                       $data->{actions});
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

    return ($status, \@users);
}

=head2 import

pf::web::guest::import_csv

=cut

sub importCSV {
    my ($self, $data, $user) = @_;

    my $logger = Log::Log4perl::get_logger(__PACKAGE__);
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
        $index{$column->{name}} = $count;
        $count++;
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
            my $pid = $row->[$index{'c_username'}];
            if ($pid !~ /$pf::person::PID_RE/) {
                $skipped++;
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
                $result = pf::temporary_password::generate($pid,
                                                           $data->{arrival_date},
                                                           $data->{actions},
                                                           $row->[$index{'c_password'}]);
                push(@users, { pid => $pid, email => $person{email}, password => $result });
                $count++;
            }
        }
        unless ($csv->eof) {
            $logger->warn("Problem with CSV file importation: " . $csv->error_diag());
            ($status, $message) = ($STATUS::INTERNAL_SERVER_ERROR, "Problem with importation: " . $csv->error_diag());
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

=over

=back

=head1 COPYRIGHT

Copyright (C) 2012 Inverse inc.

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

__PACKAGE__->meta->make_immutable;

1;
