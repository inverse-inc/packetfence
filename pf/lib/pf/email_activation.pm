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
use lib qw(/usr/local/pf/lib);
use Digest::MD5 qw(md5_hex);
use Log::Log4perl;
use MIME::Lite::TT;
use POSIX;
use Readonly;
use Time::HiRes qw(time);

# Constants
use constant EMAIL_ACTIVATION => 'email_activation';
# Status-related
Readonly::Scalar our $UNVERIFIED => 'unverified';
Readonly::Scalar our $VERIFIED => 'verified';
Readonly::Scalar our $EXPIRED => 'expired';
Readonly::Scalar our $INVALIDATED => 'invalidated'; # for example if a new code is requested
# Expiration time in seconds
Readonly::Scalar our $EXPIRATION => 31*24*60*60; # defaults to 31 days
# Default hash format version
Readonly::Scalar our $HASH_FORMAT => 1;
# Hash formats
Readonly::Scalar our $SIMPLE_MD5 => 1;
# Available default templates
Readonly::Scalar our $GUEST_TEMPLATE => 'guest_activation';
Readonly::Scalar our $SPONSOR_TEMPLATE => 'sponsor_activation';

BEGIN {
    use Exporter ();
    our ( @ISA, @EXPORT, @EXPORT_OK );
    @ISA = qw(Exporter);
    @EXPORT = qw(
        email_activation_db_prepare
        $email_activation_db_prepared
    );

    @EXPORT_OK = qw(
        view add modify delete
        view_by_name
        invalidate_codes
        validate_code
        modify_status
        create
        find_code
        $UNVERIFIED $EXPIRED $VERIFIED $INVALIDATED
        $GUEST_TEMPLATE $SPONSOR_TEMPLATE
    );
}

use pf::config;
use pf::db;
use pf::util;

# The next two variables and the _prepare sub are required for database handling magic (see pf::db)
our $email_activation_db_prepared = 0;
# in this hash reference we hold the database statements. We pass it to the query handler and he will repopulate
# the hash if required
our $email_activation_statements = {};

=head1 SUBROUTINES

TODO: This list is incomlete

=over

=cut

sub email_activation_db_prepare {
    my $logger = Log::Log4perl::get_logger('pf::email_activation');
    $logger->debug("Preparing pf::email_activation database queries");

    $email_activation_statements->{'email_activation_view_sql'} = get_db_handle()->prepare(
        qq [ SELECT code_id, mac, email, activation_code, expiration, status FROM email_activation WHERE code_id = ? ]
    );

    $email_activation_statements->{'email_activation_find_unverified_code_sql'} = get_db_handle()->prepare(
        qq [ SELECT code_id, mac, email, activation_code, expiration, status FROM email_activation 
            WHERE activation_code LIKE ? AND status = ? ]
    );

    $email_activation_statements->{'email_activation_view_by_code_sql'} = get_db_handle()->prepare(
        qq [ SELECT code_id, mac, email, activation_code, expiration, status FROM email_activation 
            WHERE activation_code= ? ]
    );

    $email_activation_statements->{'email_activation_add_sql'} = get_db_handle()->prepare(
        qq [ INSERT INTO email_activation (mac, email, activation_code, expiration, status) VALUES (?, ?, ?, ?, ?) ]
    );

    $email_activation_statements->{'email_activation_modify_status_sql'} = get_db_handle()->prepare(
        qq [ UPDATE email_activation SET status=? WHERE code_id = ? ]
    );

    $email_activation_statements->{'email_activation_delete_sql'} = get_db_handle()->prepare(
        qq [ DELETE FROM email_activation WHERE code_id = ? ]
    );

    $email_activation_statements->{'email_activation_change_status_old_same_mac_email_sql'} = get_db_handle()->prepare(
        qq [ UPDATE email_activation SET status=? WHERE mac = ? AND email = ? AND status = ? ]
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

=item view_by_code - view an email activation record by activation code. Returns an hashref

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
            'email_activation_add_sql', $data{'mac'}, $data{'email'}, $data{'activation_code'}, 
            $data{'expiration'}, $data{'status'}));
}

=item delete - delete an email activation record

=cut
sub delete {
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
    my ($mac, $email) = @_;

    return(db_query_execute(EMAIL_ACTIVATION, $email_activation_statements, 
        'email_activation_change_status_old_same_mac_email_sql', $INVALIDATED, $mac, $email, $UNVERIFIED));
}

=item create - create a new activation code

Returns the activation code

=cut
sub create {
    my ($mac, $email_addr) = @_;
    my $logger = Log::Log4perl::get_logger('pf::email_activation');

    # invalidate older codes for the same MAC / email
    invalidate_codes($mac, $email_addr);

    my %data = (
        'mac' => $mac,
        'email' => $email_addr,
        'status' => $UNVERIFIED,
    );

    # caculate activation code expiration
    $data{'expiration'} = POSIX::strftime("%Y-%m-%d %H:%M:%S", localtime(time + $EXPIRATION));

    # generate activation code
    $data{'activation_code'} = _generate_activation_code(%data);
    $logger->debug("generated new activation code for mac $mac: ".$data{'activation_code'});

    my $result = add(%data);
    if (defined($result)) {
        $logger->info("new activation code successfully generated for mac $mac");
        return $data{'activation_code'};
    } else {
        $logger->warn("something went wrong generating an activation code for mac $mac");
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
            .$data{'mac'}."|"
            .$data{'email'});
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
    $info{'activation_uri'} = "https://".$Config{'general'}{'hostname'}.".".$Config{'general'}{'domain'}
        ."/activate/$hash";

    # Hash merge. Note that on key collisions the result of view_by_code() will win
    %info = (%info, %{view_by_code($activation_code)});

    my %options; 
    $options{INCLUDE_PATH} = "$conf_dir/templates/";

    my $msg = MIME::Lite::TT->new( 
        From        =>  $info{'from'},
        To          =>  $info{'email'}, 
        Cc          =>  $info{'cc'}, 
        Subject     =>  $info{'subject'}, 
        Template    =>  "emails-$template.txt.tt",
        TmplOptions =>  \%options, 
        TmplParams  =>  \%info, 
    ); 

    $msg->send('smtp', $smtpserver, Timeout => 20);
}

sub create_and_email_activation_code {
    my ($mac, $email_addr, $template, %info) = @_;
    my $logger = Log::Log4perl::get_logger('pf::email_activation');

    my $activation_code = create($mac, $email_addr);
    if (defined($activation_code)) {
        send_email($activation_code, $template, %info);
    }
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

    # At this point, code is valid, mark it as verified and return node's MAC
    modify_status($activation_record->{'code_id'}, $VERIFIED);
    $logger->info("Activation code sent to email ".$activation_record->{'email'}." successfully verified! "
        . "Node authorized: ".$activation_record->{'mac'});
    return $activation_record;
}

# TODO: add an expire / cleanup sub

=head1 AUTHOR

Olivier Bilodeau <obilodeau@inverse.ca>

=head1 COPYRIGHT

Copyright (C) 2010 Inverse inc.

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
