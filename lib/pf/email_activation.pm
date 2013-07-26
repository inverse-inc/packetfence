package pf::email_activation;

=head1 NAME

pf::email_activation - module to view, query and manage email activations

=cut

=head1 DESCRIPTION

pf::email_activation contains the functions necessary to manage all aspects
of email activation: creation, deletion, activation, etc. It also includes 
utility methods generate activation codes and validate them.

=head1 DEVELOPER NOTES

Notice that this module doesn't export all its subs like our other modules do.
This is an attempt to shift our paradigm towards calling with package names 
and avoid the double naming. 

For ex: pf::email_activation::view() instead of 
pf::email_activation::email_activation_view()

Remove this note when it will be no longer relevant. ;)

=cut

use strict;
use warnings;

use Digest::MD5 qw(md5_hex);
use Log::Log4perl;
use POSIX;
use Readonly;
use Time::HiRes qw(time);
use Try::Tiny;

=head1 CONSTANTS

=over

=item database

=cut
use constant EMAIL_ACTIVATION => 'email_activation';

=item Status-related

=cut
Readonly::Scalar our $UNVERIFIED => 'unverified';
Readonly::Scalar our $VERIFIED => 'verified';
Readonly::Scalar our $EXPIRED => 'expired';
Readonly::Scalar our $INVALIDATED => 'invalidated'; # for example if a new code is requested

=item Expiration time (in seconds)

=cut
Readonly::Scalar our $EXPIRATION => 31*24*60*60; # defaults to 31 days

=item Hashing formats related

=cut
# Default hash format version
Readonly::Scalar our $HASH_FORMAT => 1;
# Hash formats
Readonly::Scalar our $SIMPLE_MD5 => 1;

=item Email activation types

=cut
Readonly our $SPONSOR_ACTIVATION => 'sponsor';
Readonly our $GUEST_ACTIVATION => 'guest';


=back

=cut

BEGIN {
    use Exporter ();
    our ( @ISA, @EXPORT, @EXPORT_OK );
    @ISA = qw(Exporter);
    @EXPORT = qw(
        email_activation_db_prepare
        $email_activation_db_prepared
    );

    @EXPORT_OK = qw(
        view add modify
        view_by_code
        invalidate_codes
        validate_code
        modify_status
        create
        find_code
        set_status_verified
        $UNVERIFIED $EXPIRED $VERIFIED $INVALIDATED
        $SPONSOR_ACTIVATION $GUEST_ACTIVATION
    );
}

use pf::config;
use pf::db;
use pf::util;
use pf::web::constants;
# TODO this dependency is unfortunate, ideally it wouldn't be in that direction
use pf::web::guest;

# The next two variables and the _prepare sub are required for database handling magic (see pf::db)
our $email_activation_db_prepared = 0;
# in this hash reference we hold the database statements. We pass it to the query handler and he will repopulate
# the hash if required
our $email_activation_statements = {};

=head1 SUBROUTINES

TODO: This list is incomplete

=over

=cut

sub email_activation_db_prepare {
    my $logger = Log::Log4perl::get_logger('pf::email_activation');
    $logger->debug("Preparing pf::email_activation database queries");

    $email_activation_statements->{'email_activation_view_sql'} = get_db_handle()->prepare(qq[
        SELECT code_id, pid, mac, email, activation_code, expiration, status, type
        FROM email_activation 
        WHERE code_id = ?
    ]);

    $email_activation_statements->{'email_activation_find_unverified_code_sql'} = get_db_handle()->prepare(qq[
        SELECT code_id, pid, mac, email, activation_code, expiration, status, type
        FROM email_activation 
        WHERE activation_code LIKE ? AND status = ?
    ]);

    $email_activation_statements->{'email_activation_find_code_sql'} = get_db_handle()->prepare(qq[
        SELECT code_id, pid, mac, email, activation_code, expiration, status, type
        FROM email_activation 
        WHERE activation_code LIKE ?
    ]);

    $email_activation_statements->{'email_activation_view_by_code_sql'} = get_db_handle()->prepare(qq[
        SELECT code_id, pid, mac, email, activation_code, expiration, status, type
        FROM email_activation 
        WHERE activation_code = ?
    ]);

    $email_activation_statements->{'email_activation_add_sql'} = get_db_handle()->prepare(qq[
        INSERT INTO email_activation (pid, mac, email, activation_code, expiration, status, type) 
        VALUES (?, ?, ?, ?, ?, ?, ?)
    ]);

    $email_activation_statements->{'email_activation_modify_status_sql'} = get_db_handle()->prepare(
        qq [ UPDATE email_activation SET status=? WHERE code_id = ? ]
    );

    $email_activation_statements->{'email_activation_delete_sql'} = get_db_handle()->prepare(
        qq [ DELETE FROM email_activation WHERE code_id = ? ]
    );

    $email_activation_statements->{'email_activation_change_status_old_same_mac_email_sql'} = get_db_handle()->prepare(
        qq [ UPDATE email_activation SET status=? WHERE mac = ? AND email = ? AND status = ? ]
    );

    $email_activation_statements->{'email_activation_change_status_old_same_pid_email_sql'} = get_db_handle()->prepare(
        qq [ UPDATE email_activation SET status=? WHERE pid = ? AND email = ? AND status = ? ]
    );

    $email_activation_db_prepared = 1;
}

=item view - view a an email activation record, returns an hashref

=cut
sub view {
    my ($code_id) = @_;
    my $query = db_query_execute(EMAIL_ACTIVATION, $email_activation_statements, 'email_activation_view_sql', $code_id);
    my $ref = $query->fetchrow_hashref();

    # just get one row and finish
    $query->finish();
    return ($ref);
}

=item find_code - view an email activation record by activation code without hash-format. Returns an hashref

=cut
sub find_code {
    my ($activation_code) = @_;
    my $query = db_query_execute(EMAIL_ACTIVATION, $email_activation_statements, 
        'email_activation_find_code_sql', '%'.$activation_code);
    my $ref = $query->fetchrow_hashref();

    # just get one row and finish
    $query->finish();
    return ($ref);
}

=item find_unverified_code - find an unused email activation record by doing a LIKE in the code, returns an hashref

=cut
sub find_unverified_code {
    my ($activation_code) = @_;
    my $query = db_query_execute(EMAIL_ACTIVATION, $email_activation_statements, 
        'email_activation_find_unverified_code_sql', "%".$activation_code, $UNVERIFIED);
    my $ref = $query->fetchrow_hashref();

    # just get one row and finish
    $query->finish();
    return ($ref);
}

=item view_by_code - view an email activation record by exact activation code (including hash format). Returns an hashref

=cut
sub view_by_code {
    my ($activation_code) = @_;
    my $query = db_query_execute(EMAIL_ACTIVATION, $email_activation_statements, 
        'email_activation_view_by_code_sql', $activation_code);
    my $ref = $query->fetchrow_hashref();

    # just get one row and finish
    $query->finish();
    return ($ref);
}

=item add - add an email activation record to the database

=cut
sub add {
    my (%data) = @_;

    # TODO some validation required?

    return(db_data(EMAIL_ACTIVATION, $email_activation_statements, 
            'email_activation_add_sql', $data{'pid'}, $data{'mac'}, $data{'email'}, $data{'activation_code'}, 
            $data{'expiration'}, $data{'status'}, $data{'type'}));
}

=item _delete - delete an email activation record

=cut
sub _delete {
    my ($code_id) = @_;

    return(db_query_execute(EMAIL_ACTIVATION, $email_activation_statements, 'email_activation_delete_sql', $code_id));
}

=item modify_status - update the status of a given email activation record

=cut
sub modify_status {
    my ($code_id, $new_status) = @_;

    return(db_query_execute(EMAIL_ACTIVATION, $email_activation_statements, 
        'email_activation_modify_status_sql', $new_status, $code_id));
}

=item invalidate_code - invalidate all unverified activation codes for a given mac and email

=cut
sub invalidate_codes {
    my ($mac, $pid, $email) = @_;
    my $logger = Log::Log4perl::get_logger('pf::email_activation');

    db_query_execute(EMAIL_ACTIVATION, $email_activation_statements, 
        'email_activation_change_status_old_same_pid_email_sql', $INVALIDATED, $pid, $email, $UNVERIFIED
    ) || $logger->warn("problems trying to invalidate activation codes using pid $pid");

    db_query_execute(EMAIL_ACTIVATION, $email_activation_statements, 
        'email_activation_change_status_old_same_mac_email_sql', $INVALIDATED, $mac, $email, $UNVERIFIED
    ) || $logger->warn("problems trying to invalidate activation codes using mac $mac");

    return;
}

=item create - create a new activation code

Returns the activation code

=cut
sub create {
    my ($mac, $pid, $email_addr, $activation_type) = @_;
    my $logger = Log::Log4perl::get_logger('pf::email_activation');

    # invalidate older codes for the same MAC / email
    invalidate_codes($mac, $pid, $email_addr);

    my %data = (
        'pid' => $pid,
        'mac' => $mac,
        'email' => $email_addr,
        'status' => $UNVERIFIED,
        'type' => $activation_type,
    );

    # caculate activation code expiration
    $data{'expiration'} = POSIX::strftime("%Y-%m-%d %H:%M:%S", localtime(time + $EXPIRATION));

    # generate activation code
    $data{'activation_code'} = _generate_activation_code(%data);
    $logger->debug("generated new activation code: ".$data{'activation_code'});

    my $result = add(%data);
    if (defined($result)) {
        $logger->info("new activation code successfully generated");
        return $data{'activation_code'};
    } else {
        $logger->warn("something went wrong generating an activation code for " . $mac || $pid);
        return;
    }
}

=item _generate_activation_code - generate proper activation code. Created to encapsulate flexible hash types.

=cut
sub _generate_activation_code {
    my (%data) = @_;
    my $logger = Log::Log4perl::get_logger('pf::email_activation');

    if ($HASH_FORMAT == $SIMPLE_MD5) {
        # generating something not so easy to guess (and hopefully not in rainbowtables)
        return "$SIMPLE_MD5:".md5_hex(
            time."|"
            .$data{'expiration'}."|"
            . $data{'mac'} || $data{'pid'} . "|"
            .$data{'email'}
        );
    } else {
        $logger->warn("Hash format unknown, couldn't generate activation code");
    }
}

=item _unpack_activation_code - grab the hash-format and the activation hash out of the activation code

Returns a list of: hash version, hash

=cut
sub _unpack_activation_code {
    my ($activation_code) = @_;

    if ($activation_code =~ /^(\d+):(\w+)$/) {
        return ($1, $2);
    }
    # return undef on failure
    return;
}

=item send_email - Send an email with the activation code

=cut
sub send_email {
    my ($activation_code, $template, %info) = @_;
    my $logger = Log::Log4perl::get_logger('pf::email_activation');

    my $smtpserver = $Config{'alerting'}{'smtpserver'};
    $info{'from'} = $Config{'alerting'}{'fromaddr'} || 'root@' . $fqdn;
    $info{'currentdate'} = POSIX::strftime( "%m/%d/%y %H:%M:%S", localtime );
    my ($hash_version, $hash) = _unpack_activation_code($activation_code);

    if (defined($info{'activation_domain'})) {
        $info{'activation_uri'} = "https://". $info{'activation_domain'} . "$WEB::URL_EMAIL_ACTIVATION_LINK/$hash";
    } else {
        $info{'activation_uri'} = "https://".$Config{'general'}{'hostname'}.".".$Config{'general'}{'domain'}
            ."$WEB::URL_EMAIL_ACTIVATION_LINK/$hash";
    }

    # Hash merge. Note that on key collisions the result of view_by_code() will win
    %info = (%info, %{view_by_code($activation_code)});

    my %options; 
    $options{INCLUDE_PATH} = "$conf_dir/templates/";

    my $import_succesfull = try { require MIME::Lite::TT; };
    if (!$import_succesfull) {
        $logger->error(
            "Could not send email because I couldn't load a module. ".
            "Are you sure you have MIME::Lite::TT installed?"
        );
        return $FALSE;
    }
    my $msg = MIME::Lite::TT->new( 
        From        =>  $info{'from'},
        To          =>  $info{'email'}, 
        Cc          =>  $info{'cc'},
        Subject     =>  $info{'subject'},
        Template    =>  "emails-$template.txt.tt",
        TmplOptions =>  \%options, 
        TmplParams  =>  \%info, 
    ); 

    my $result = 0;
    try {
      $msg->send('smtp', $smtpserver, Timeout => 20);
      $result = $msg->last_send_successful();
    }
    catch {
      $logger->error("Can't send email to ".$info{'email'});
    };
    
    return $result;
}

sub create_and_email_activation_code {
    my ($mac, $pid, $email_addr, $template, $activation_type, %info) = @_;
    my $logger = Log::Log4perl::get_logger('pf::email_activation');

    my ($success, $err) = ($TRUE, 0);
    my $activation_code = create($mac, $pid, $email_addr, $activation_type);
    if (defined($activation_code)) {
      unless (send_email($activation_code, $template, %info)) {
        ($success, $err) = ($FALSE, $GUEST::ERROR_CONFIRMATION_EMAIL);
      }
    }

    return ($success, $err);
}

# returns the validated activation record hashref or undef
sub validate_code {
    my ($activation_code) = @_;
    my $logger = Log::Log4perl::get_logger('pf::email_activation');

    my $activation_record = find_unverified_code($activation_code);
    if (!defined($activation_record) || ref($activation_record eq 'HASH')) {
        $logger->info("Unable to retrieve email activation entry based on activation code: $activation_code");
        return;
    }

    # Force a solid match.
    my ($hash_version, $hash) = _unpack_activation_code($activation_record->{'activation_code'});
    if ($activation_code ne $hash) {
        $logger->info("Activation code is not exactly the same as the one on record. $activation_code != $hash");
        return;
    }

    # At this point, code is validated: return the activation record
    $logger->info("Activation code sent to email $activation_record->{email} successfully verified! "
        . "Node authorized: $activation_record->{mac} of activation type: $activation_record->{type}"
    );
    return $activation_record;
}

=item set_status_verified 

Change the status of a given email activation code to VERIFIED which means it can't be used anymore.

=cut
sub set_status_verified {
    my ($activation_code) = @_;
    my $logger = Log::Log4perl::get_logger(__PACKAGE__);

    my $activation_record = find_code($activation_code);
    modify_status($activation_record->{'code_id'}, $VERIFIED);
}

# TODO: add an expire / cleanup sub

=back

=head1 AUTHOR

Inverse inc. <info@inverse.ca>

=head1 COPYRIGHT

Copyright (C) 2005-2013 Inverse inc.

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
