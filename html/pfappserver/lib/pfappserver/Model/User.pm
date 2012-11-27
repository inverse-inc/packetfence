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
use pf::temporary_password;
use pf::error qw(is_error is_success);
use pf::person qw(person_modify $PID_RE);
use pf::util qw(get_translatable_time);

=head2 read

=cut

sub read {
    my ($self, $c, $pids) = @_;

    my @users;
    
    # Fetch user information
    foreach my $p (@$pids) {
        my $user = pf::temporary_password::view($p);
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

    if (scalar @users > 0) {
        $status_msg = \@users;
    }
    else {
        $status = $STATUS::INTERNAL_SERVER_ERROR;
        $status_msg = 'Unexpected error. See server-side logs for details.';
    }

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
    my $expiration;
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

        # Expiration is arrival date + access duration + a tolerance window of 24 hrs
        $expiration = POSIX::strftime("%Y-%m-%d %H:%M:%S", 
                                      localtime(str2time($data->{arrival_date}) +
                                                normalize_time($data->{access_duration}) + 
                                                24*60*60));

        # We create temporary password with the expiration and a 'not valid before' value
        $result = pf::temporary_password::generate($pid,
                                                   $expiration,
                                                   $data->{arrival_date},
                                                   $data->{access_duration});
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
    my $expiration;
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
            # Expiration is arrival date + access duration + a tolerance window of 24 hrs
            $expiration = POSIX::strftime("%Y-%m-%d %H:%M:%S", 
                                          localtime(str2time($data->{arrival_date}) +
                                                    normalize_time($data->{access_duration}) + 
                                                    24*60*60));

            # Create/update password
            $result = pf::temporary_password::generate($pid,
                                                       $expiration,
                                                       $data->{arrival_date}, 
                                                       $data->{access_duration});
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
    
    # Expiration is arrival date + access duration + a tolerance window of 24 hrs
    my $expiration = POSIX::strftime("%Y-%m-%d %H:%M:%S", 
                                     localtime(str2time($data->{arrival_date}) +
                                               normalize_time($data->{access_duration}) + 
                                               24*60*60));

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
            if ($pid !~ /$PID_RE/) {
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
                                                           $expiration,
                                                           $data->{arrival_date}, 
                                                           $data->{access_duration},
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
