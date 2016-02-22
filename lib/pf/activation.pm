package pf::activation;

=head1 NAME

pf::activation - module to view, query and manage pending activations

=cut

=head1 DESCRIPTION

pf::activation contains the functions necessary to manage all aspects
of pending activation: creation, deletion, activation, etc. It also includes
utility methods generate activation codes and validate them.

=head1 DEVELOPER NOTES

Notice that this module doesn't export all its subs like our other modules do.
This is an attempt to shift our paradigm towards calling with package names
and avoid the double naming.

For ex: pf::activation::view() instead of
pf::activation::activation_view()

Remove this note when it will be no longer relevant. ;)

=cut

use strict;
use warnings;

use Digest::MD5 qw(md5_hex);
use POSIX;
use Readonly;
use Time::HiRes qw(time);
use Try::Tiny;
use MIME::Lite;
use Encode qw(encode);

=head1 CONSTANTS

=head2 database

=cut

use constant ACTIVATION => 'activation';

=head2 Status-related

=cut

Readonly::Scalar our $UNVERIFIED => 'unverified';
Readonly::Scalar our $VERIFIED => 'verified';
Readonly::Scalar our $EXPIRED => 'expired';
Readonly::Scalar our $INVALIDATED => 'invalidated'; # for example if a new code is requested

=head2 Expiration time (in seconds)

=cut

Readonly::Scalar our $EXPIRATION => 31*24*60*60; # defaults to 31 days

=head2 Hashing formats related

=cut

# Default hash format version
Readonly::Scalar our $HASH_FORMAT => 1;
# Hash formats
Readonly::Scalar our $SIMPLE_MD5 => 1;

=head2 Email activation types


=cut

Readonly our $SPONSOR_ACTIVATION => 'sponsor';
Readonly our $GUEST_ACTIVATION => 'guest';


BEGIN {
    use Exporter ();
    our ( @ISA, @EXPORT, @EXPORT_OK );
    @ISA = qw(Exporter);
    @EXPORT = qw(
        activation_db_prepare
        $activation_db_prepared
    );

    @EXPORT_OK = qw(
        view add modify
        view_by_code
        invalidate_codes
        invalidate_codes_for_mac
        validate_code
        modify_status
        create
        find_code
        set_status_verified
        $UNVERIFIED $EXPIRED $VERIFIED $INVALIDATED
        $SPONSOR_ACTIVATION $GUEST_ACTIVATION
    );
}

use pf::constants;
use pf::config;
use pf::db;
use pf::util;
use pf::web::constants;
# TODO this dependency is unfortunate, ideally it wouldn't be in that direction
use pf::web::guest;
use pf::log;

# The next two variables and the _prepare sub are required for database handling magic (see pf::db)
our $activation_db_prepared = 0;
# in this hash reference we hold the database statements. We pass it to the query handler and he will repopulate
# the hash if required
our $activation_statements = {};

=head1 SUBROUTINES

TODO: This list is incomplete

=cut

sub activation_db_prepare {
    my $logger = get_logger();
    $logger->debug("Preparing pf::activation database queries");

    $activation_statements->{'activation_view_sql'} = get_db_handle()->prepare(qq[
        SELECT code_id, pid, mac, contact_info, activation_code, expiration, status, type, portal, email_pattern as carrier_email_pattern
        FROM activation LEFT JOIN sms_carrier ON carrier_id=sms_carrier.id
        WHERE code_id = ?
    ]);

    $activation_statements->{'activation_find_unverified_code_sql'} = get_db_handle()->prepare(qq[
        SELECT code_id, pid, mac, contact_info, activation_code, expiration, status, type, portal, email_pattern as carrier_email_pattern
        FROM activation LEFT JOIN sms_carrier ON carrier_id=sms_carrier.id
        WHERE activation_code = ? AND status = ?
    ]);

    $activation_statements->{'activation_find_code_sql'} = get_db_handle()->prepare(qq[
        SELECT code_id, pid, mac, contact_info, activation_code, expiration, status, type, portal, email_pattern as carrier_email_pattern
        FROM activation LEFT JOIN sms_carrier ON carrier_id=sms_carrier.id
        WHERE activation_code LIKE ?
    ]);

    $activation_statements->{'activation_view_by_code_sql'} = get_db_handle()->prepare(qq[
        SELECT code_id, pid, mac, contact_info, activation_code, expiration, status, type, portal, email_pattern as carrier_email_pattern
        FROM activation LEFT JOIN sms_carrier ON carrier_id=sms_carrier.id
        WHERE activation_code = ?
    ]);

    $activation_statements->{'activation_add_sql'} = get_db_handle()->prepare(qq[
        INSERT INTO activation (pid, mac, contact_info, carrier_id, activation_code, expiration, status, type, portal)
        VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)
    ]);

    $activation_statements->{'activation_modify_status_sql'} = get_db_handle()->prepare(
        qq [ UPDATE activation SET status=? WHERE code_id = ? ]
    );

    $activation_statements->{'activation_delete_sql'} = get_db_handle()->prepare(
        qq [ DELETE FROM activation WHERE code_id = ? ]
    );

    $activation_statements->{'activation_change_status_old_same_mac_pid_contact_info_sql'} = get_db_handle()->prepare(
        qq [ UPDATE activation SET status = ? WHERE mac = ? AND pid = ? AND contact_info = ? AND status = ? ]
    );

    $activation_statements->{'activation_change_status_by_mac_type_sql'} = get_db_handle()->prepare(
        qq [ UPDATE activation SET status = ? WHERE mac = ? AND type = ? AND status = ? ]
    );

    $activation_statements->{'activation_change_status_old_same_pid_contact_info_sql'} = get_db_handle()->prepare(
        qq [ UPDATE activation SET status = ? WHERE mac IS NULL AND pid = ? AND contact_info = ? AND status = ? ]
    );


    $activation_statements->{'activation_has_entry_sql'} = get_db_handle()->prepare(
        qq [ SELECT 1 FROM activation WHERE mac = ? AND expiration >= NOW() AND status = ? AND type = ? ]
    );

    $activation_db_prepared = 1;
}

=head2 view

view a an pending activation record, returns an hashref

=cut

sub view {
    my ($code_id) = @_;
    my $query = db_query_execute(ACTIVATION, $activation_statements, 'activation_view_sql', $code_id);
    my $ref = $query->fetchrow_hashref();

    # just get one row and finish
    $query->finish();
    return ($ref);
}

=head2 find_code

view an pending activation record by activation code without hash-format. Returns an hashref

=cut

sub find_code {
    my ($activation_code) = @_;
    my $query = db_query_execute(ACTIVATION, $activation_statements,
        'activation_find_code_sql', '%'.$activation_code);
    my $ref = $query->fetchrow_hashref();

    # just get one row and finish
    $query->finish();
    return ($ref);
}

=head2 find_unverified_code

find an unused pending activation record by doing a LIKE in the code, returns an hashref

=cut

sub find_unverified_code {
    my ($activation_code) = @_;
    my $query = db_query_execute(ACTIVATION, $activation_statements,
        'activation_find_unverified_code_sql',
        "${HASH_FORMAT}:${activation_code}", $UNVERIFIED
    );
    my $ref = $query->fetchrow_hashref();

    # just get one row and finish
    $query->finish();
    return ($ref);
}

=head2 view_by_code

view an pending  activation record by exact activation code (including hash format). Returns an hashref

=cut

sub view_by_code {
    my ($activation_code) = @_;
    my $query = db_query_execute(ACTIVATION, $activation_statements,
        'activation_view_by_code_sql', $activation_code);
    my $ref = $query->fetchrow_hashref();

    # just get one row and finish
    $query->finish();
    return ($ref);
}

=head2 add

add an pending activation record to the database

=cut

sub add {
    my (%data) = @_;

    # TODO some validation required?

    return(db_data(ACTIVATION, $activation_statements,
            'activation_add_sql', $data{'pid'}, $data{'mac'}, $data{'contact_info'},$data{'carrier_id'}, $data{'activation_code'},
            $data{'expiration'}, $data{'status'}, $data{'type'}, $data{'portal'}));
}

=head2 _delete

delete an pending activation record

=cut

sub _delete {
    my ($code_id) = @_;

    return(db_query_execute(ACTIVATION, $activation_statements, 'activation_delete_sql', $code_id));
}

=head2 modify_status

update the status of a given pending activation record

=cut

sub modify_status {
    my ($code_id, $new_status) = @_;

    return(db_query_execute(ACTIVATION, $activation_statements,
        'activation_modify_status_sql', $new_status, $code_id));
}

=head2 invalidate_codes

invalidate all unverified activation codes for a given mac and contact_info

=cut

sub invalidate_codes {
    my ($mac, $pid, $contact_info) = @_;
    my $logger = get_logger();

    if ($mac) {
        # Invalidate previous activation codes matching MAC, pid (user or sponsor email) and contact_info
        db_query_execute(ACTIVATION, $activation_statements,
                         'activation_change_status_old_same_mac_pid_contact_info_sql', $INVALIDATED, $mac, $pid, $contact_info, $UNVERIFIED
                        ) || $logger->warn("problems trying to invalidate activation codes using mac $mac");
    } else {
        # Invalidate previous activation with no MAC address (pre-registration)
        db_query_execute(ACTIVATION, $activation_statements,
                         'activation_change_status_old_same_pid_contact_info_sql', $INVALIDATED, $pid, $contact_info, $UNVERIFIED
                        ) || $logger->warn("problems trying to invalidate activation codes using pid $pid");
    }

    return;
}

=head2 invalidate_codes_for_mac

invalidate codes for mac

=cut

sub invalidate_codes_for_mac {
    my ($mac, $type) = @_;
    my $logger = get_logger();
    if ($mac) {
        # Invalidate previous activation codes matching MAC, pid (user or sponsor email) and contact_info
        db_query_execute(ACTIVATION, $activation_statements,
                         'activation_change_status_by_mac_type_sql', $INVALIDATED, $mac, $type, $UNVERIFIED

                        ) || $logger->warn("problems trying to invalidate activation codes using mac $mac");
    }
    return ;
}

=head2 create

create a new activation code

Returns the activation code

=cut

sub create {
    my ($mac, $pid, $pending_addr, $type, $portal, $provider_id) = @_;
    my $logger = get_logger();

    # invalidate older codes for the same MAC / contact_info
    invalidate_codes($mac, $pid, $pending_addr);

    my %data = (
        'pid' => $pid,
        'mac' => $mac,
        'contact_info' => $pending_addr,
        'status' => $UNVERIFIED,
        'type' => $type,
        'portal' => $portal,
        'carrier_id' => $provider_id,
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

=head2 _generate_activation_code

generate proper activation code. Created to encapsulate flexible hash types.

=cut

sub _generate_activation_code {
    my (%data) = @_;
    my $logger = get_logger();

    if ($HASH_FORMAT == $SIMPLE_MD5) {
        my $code;
        do {
            # generating something not so easy to guess (and hopefully not in rainbowtables)
            my $hash = md5_hex(
                join("|",
                    time + int(rand(10)),
                    grep {defined $_} @data{qw(expiration mac pid contact_info)})
            );
            # - taking out a couple of hex (avoids overflow in step below)
            # then keeping first 8
            if($data{'type'} eq 'sms') {
                $code = "$SIMPLE_MD5:". substr($hash, 0, 8);
            } else {
                $code = "$SIMPLE_MD5:". $hash;
            }
            # make sure the generated code is unique
            $code = undef if (view_by_code($code));
        } while (!defined($code));

        return $code;
    } else {
        $logger->warn("Hash format unknown, couldn't generate activation code");
    }
}

=head2 _unpack_activation_code

grab the hash-format and the activation hash out of the activation code

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

=head2 send_email

Send an email with the activation code

=cut

sub send_email {
    my ($activation_code, $template, %info) = @_;
    my $logger = get_logger();

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

    my $import_succesfull = try { require MIME::Lite::TT; };
    if (!$import_succesfull) {
        $logger->error(
            "Could not send email because I couldn't load a module. ".
            "Are you sure you have MIME::Lite::TT installed?"
        );
        return $FALSE;
    }

    my %TmplOptions = (
        INCLUDE_PATH    => "$conf_dir/templates/",
        ENCODING        => 'utf8',
    );
    utf8::decode($info{'subject'});
    my $msg = MIME::Lite::TT->new(
        From        =>  $info{'from'},
        To          =>  $info{'contact_info'},
        Cc          =>  $info{'cc'},
        Subject     =>  encode("MIME-Header", $info{'subject'}),
        Template    =>  "emails-$template.html",
        TmplOptions =>  \%TmplOptions,
        TmplParams  =>  \%info,
        TmplUpgrade =>  1,
    );
    $msg->attr("Content-Type" => "text/html; charset=UTF-8;");

    my $result = 0;
    try {
      $msg->send('smtp', $smtpserver, Timeout => 20);
      $result = $msg->last_send_successful();
      $logger->info("Email sent to ".$info{'contact_info'}." (".$info{'subject'}.")");
    }
    catch {
      $logger->error("Can't send email to ".$info{'contact_info'}.": $!");
    };

    return $result;
}

sub create_and_send_activation_code {
    my ($mac, $pid, $pending_addr, $template, $type, $portal, %info) = @_;

    my ($success, $err) = ($TRUE, 0);
    my $activation_code = create($mac, $pid, $pending_addr, $type, $portal);
    if (defined($activation_code)) {
      unless (send_email($activation_code, $template, %info)) {
        ($success, $err) = ($FALSE, $GUEST::ERROR_CONFIRMATION_EMAIL);
      }
    }

    return ($success, $err, $activation_code);
}

# returns the validated activation record hashref or undef
sub validate_code {
    my ($activation_code) = @_;
    my $logger = get_logger();

    my $activation_record = find_unverified_code($activation_code);
    if (!defined($activation_record) || ref($activation_record eq 'HASH')) {
        $logger->info("Unable to retrieve pending activation entry based on activation code: $activation_code");
        return;
    }

    # Force a solid match.
    my ($hash_version, $hash) = _unpack_activation_code($activation_record->{'activation_code'});
    if ($activation_code ne $hash) {
        $logger->info("Activation code is not exactly the same as the one on record. $activation_code != $hash");
        return;
    }

    # At this point, code is validated: return the activation record
    $logger->info(($activation_record->{mac}?"[$activation_record->{mac}]":"[unknown]") . " Activation code sent to email $activation_record->{contact_info} from $activation_record->{pid} successfully verified. "
                . " for activation type: $activation_record->{type}");
    return $activation_record;
}

=head2 set_status_verified

Change the status of a given pending activation code to VERIFIED which means it can't be used anymore.

=cut

sub set_status_verified {
    my ($activation_code) = @_;
    my $logger = get_logger();

    my $activation_record = find_code($activation_code);
    modify_status($activation_record->{'code_id'}, $VERIFIED);
}


sub activation_has_entry {
    my ($mac,$type) = @_;
    my $query = db_query_execute(ACTIVATION, $activation_statements, 'activation_has_entry_sql', $mac, $UNVERIFIED, $type);
    my $rows = $query->rows;
    $query->finish;
    return $rows;
}

=head2 sms_activation_create_send

Create and send PIN code

=cut

#The attribute %info is only meant to be used for debugging purposes.

sub sms_activation_create_send {
    my ($mac, $pid, $phone_number, $portal, $provider_id, %info) = @_;
    my $logger = get_logger();

    # Strip non-digits
    $phone_number =~ s/\D//g;

    my ($success, $err) = ($TRUE, 0);
    my $activation_code = create($mac, $pid, $phone_number, 'sms', $portal, $provider_id);
    if (defined($activation_code)) {
      unless (send_sms($activation_code, %info)) {
        ($success, $err) = ($FALSE, $GUEST::ERROR_CONFIRMATION_SMS);
      }
    }

    return ($success, $err, $activation_code);
}

=head2 send_sms -

Send SMS with activation code

=cut

sub send_sms {
    my ($activation_code, %info) = @_;
    my $logger = get_logger();

    my $smtpserver = $Config{'alerting'}{'smtpserver'};
    $info{'from'} = $Config{'alerting'}{'fromaddr'} || 'root@' . $fqdn;
    $info{'currentdate'} = POSIX::strftime( "%m/%d/%y %H:%M:%S", localtime );
    my ($hash_version, $pin) = _unpack_activation_code($activation_code);

    # Hash merge. Note that on key collisions the result of view_by_code() will win
    %info = (%info, %{view_by_code($activation_code)});

    my $email = sprintf($info{'carrier_email_pattern'}, $info{'contact_info'});
    my $msg = MIME::Lite->new(
        From        =>  $info{'from'},
        To          =>  $email,
        Subject     =>  "Network Activation",
        Data        =>  "PIN: $pin"
    );

    my $result = 0;
    eval {
      $msg->send('smtp', $smtpserver, Timeout => 20);
      $result = $msg->last_send_successful();
      $logger->info("Email sent to $email (Network Activation)");
    };
    if ($@) {
      my $msg = "Can't send email to $email: $@";
      $msg =~ s/\n//g;
      $logger->error($msg);
    }

    return $result;
}

# TODO: add an expire / cleanup sub

=head1 AUTHOR

Inverse inc. <info@inverse.ca>

=head1 COPYRIGHT

Copyright (C) 2005-2016 Inverse inc.

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
