package pf::sms_activation;

=head1 NAME

pf::sms_activation

=cut

# TODO consider refactoring with pf::email_activation to regroup some functionality
use strict;
use warnings;

use Digest::MD5 qw(md5_hex);
use Locale::gettext;
use Log::Log4perl;
use MIME::Lite::TT;
use POSIX;
use Readonly;
use Time::HiRes qw(time);

use pf::config;
use pf::db;
use pf::iplog qw(ip2mac);
# TODO this dependency is unfortunate, ideally it wouldn't be in that direction
use pf::web::guest;

# Constants
use constant SMS_ACTIVATION => 'sms_activation';
# Status-related
Readonly::Scalar our $UNVERIFIED => 'unverified';
Readonly::Scalar our $VERIFIED => 'verified';
Readonly::Scalar our $EXPIRED => 'expired';
Readonly::Scalar our $INVALIDATED => 'invalidated'; # for example if a new code is requested
# Expiration time of activation code in seconds
Readonly::Scalar our $EXPIRATION => 31*24*60*60; # defaults to 31 days
# Default hash format version
Readonly::Scalar our $HASH_FORMAT => 1;
# Hash formats
Readonly::Scalar our $SIMPLE_MD5 => 1;

BEGIN {
    use Exporter ();
    our ( @ISA, @EXPORT );
    @ISA    = qw(Exporter);
    @EXPORT = qw(
        sms_carrier_view_all
        validate_phone_number
        sms_activation_create_send
        validate_code
    );
}

# The next two variables and the _prepare sub are required for database handling magic (see pf::db)
our $sms_activation_db_prepared = 0;
# in this hash reference we hold the database statements. We pass it to the query handler and he will repopulate
# the hash if required
our $sms_activation_statements = {};

=head1 SUBROUTINES

=over

=item sms_activation_db_prepare

=cut
sub sms_activation_db_prepare {
    my $logger = Log::Log4perl::get_logger('pf::sms_activation');
    $logger->debug("Preparing pf::sms_activation database queries");

    $sms_activation_statements->{'sms_activation_carrier_view_all_sql'} = get_db_handle()->prepare(qq[
        SELECT id, name
        FROM sms_carrier
    ]);

    $sms_activation_statements->{'sms_activation_view_sql'} = get_db_handle()->prepare(qq[
        SELECT code_id, mac, phone_number, carrier_id, activation_code, expiration, status 
        FROM sms_activation 
        WHERE code_id = ?
    ]);

    $sms_activation_statements->{'sms_activation_find_unverified_code_sql'} = get_db_handle()->prepare(qq[
        SELECT code_id, mac, phone_number, carrier_id, activation_code, expiration, status FROM sms_activation
        WHERE activation_code LIKE ? AND status = ?
    ]);

    $sms_activation_statements->{'sms_activation_view_by_code_sql'} = get_db_handle()->prepare(qq[
        SELECT code_id, mac, phone_number, email_pattern as carrier_email_pattern, activation_code, expiration, status 
        FROM sms_activation LEFT JOIN sms_carrier ON carrier_id=sms_carrier.id
        WHERE activation_code = ?
    ]);

    $sms_activation_statements->{'sms_activation_add_sql'} = get_db_handle()->prepare(qq[
        INSERT INTO sms_activation (
            mac, phone_number, carrier_id, activation_code, expiration, status
        ) VALUES (?, ?, ?, ?, ?, ?) 
    ]);

    $sms_activation_statements->{'sms_activation_modify_status_sql'} = get_db_handle()->prepare(
        qq [ UPDATE sms_activation SET status=? WHERE code_id = ? ]
    );

#    $sms_activation_statements->{'sms_activation_delete_sql'} = get_db_handle()->prepare(
#        qq [ DELETE FROM sms_activation WHERE code_id = ? ]
#    );

    $sms_activation_statements->{'sms_activation_change_status_old_same_mac_phone_sql'} = get_db_handle()->prepare(
        qq [ UPDATE sms_activation SET status=? WHERE mac = ? AND phone_number = ? AND status = ? ]
    );

    $sms_activation_db_prepared = 1;
}

=item sms_carrier_view_all

=cut
sub sms_carrier_view_all {
    my $query = db_query_execute(SMS_ACTIVATION, $sms_activation_statements, 
                                 'sms_activation_carrier_view_all_sql');

    my $val = $query->fetchall_arrayref({});
    my $logger = Log::Log4perl::get_logger('pf::sms_activation');

    $query->finish();
    return $val;
}

#sub sms_activation_insert_start {
#    my ( $switch, $ifIndex, $location, $description ) = @_;
#    sms_activation_db_prepare($dbh) if ( !$sms_activation_db_prepared );
#    $sms_activation_insert_start_sql->execute( $switch, $ifIndex, $location,
#        $description )
#        || return (0);
#    return (1);
#},

=item validate_phone_number

Returns phone number in xxxyyyzzzz format if valid undef otherwise.

=cut
sub validate_phone_number {
    my ($phone_number) = @_;
    if ($phone_number =~ /
        ^\(?([2-9]\d{2})\)?  # captures first 3 digits allows optional parenthesis
        (?:-|.|\s)?          # separator -, ., sapce or nothing
        (\d{3})              # captures 3 digits
        (?:-|.|\s)?          # separator -, ., sapce or nothing
        (\d{4})$             # captures last 4 digits
        /x) {
        return "$1$2$3";
    }
    return;
}

=item add - add an sms activation record to the database

=cut
sub add {
    my (%data) = @_;

    return(db_data(SMS_ACTIVATION, $sms_activation_statements,
                   'sms_activation_add_sql', $data{'mac'}, $data{'phone_number'}, $data{'carrier_id'},
                   $data{'activation_code'}, $data{'expiration'}, $data{'status'}));
}

=item invalidate_code - invalidate all unverified PIN codes for a given mac and phone 

=cut
sub invalidate_codes {
    my ($mac, $phone) = @_;

    return(db_query_execute(SMS_ACTIVATION, $sms_activation_statements, 
                            'sms_activation_change_status_old_same_mac_phone_sql', $INVALIDATED, $mac, $phone, $UNVERIFIED));
}

=item _generate_activation_code - generate proper PIN code. Created to encapsulate flexible hash types.

=cut
sub _generate_activation_code {
    my (%data) = @_;
    my $logger = Log::Log4perl::get_logger('pf::sms_activation');

    if ($HASH_FORMAT == $SIMPLE_MD5) {
        # generating something not so easy to guess (and hopefully not in rainbowtables)
        my $hash = md5_hex(
            time."|"
            .$data{'expiration'}."|"
            .$data{'mac'}."|"
            .$data{'phone_number'});
        # - taking out a couple of hex (avoids overflow in step below)
        # - converting from hex to digits (easier to type on phone)
        # then keeping first 5
        return "$SIMPLE_MD5:". substr(hex(substr($hash, 0, 6)), 0, 5);
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

=item modify_status - update the status of a given email activation record

=cut
sub modify_status {
    my ($code_id, $new_status) = @_;
    return(db_query_execute(SMS_ACTIVATION, $sms_activation_statements, 
                            'sms_activation_modify_status_sql', $new_status, $code_id));
}

=item view_by_code - view an SMS activation record by activation code. Returns an hashref

=cut
sub view_by_code {
    my ($activation_code) = @_;
    my $query = db_query_execute(SMS_ACTIVATION, $sms_activation_statements, 
                                 'sms_activation_view_by_code_sql', $activation_code);
    my $ref = $query->fetchrow_hashref();
    my $logger = Log::Log4perl::get_logger('pf::sms_activation');
    
    # just get one row and finish
    $query->finish();
    return ($ref);
}

=item find_unverified_code - find an unused activation record by doing a LIKE in the code, returns an hashref

=cut
sub find_unverified_code {
    my ($activation_code) = @_;
    my $query = db_query_execute(SMS_ACTIVATION, $sms_activation_statements, 
                                 'sms_activation_find_unverified_code_sql', "%".$activation_code, $UNVERIFIED);
    my $ref = $query->fetchrow_hashref();
    
    # just get one row and finish
    $query->finish();
    return ($ref);
}

=item create - create a new PIN code

Returns the PIN code

=cut
sub create {
    my ($mac, $phone_number, $provider_id) = @_;
    my $logger = Log::Log4perl::get_logger('pf::sms_activation');

    # invalidate older codes for the same MAC / phone
    invalidate_codes($mac, $phone_number);

    my %data = (
        'mac' => $mac,
        'phone_number' => $phone_number,
        'carrier_id' => $provider_id,
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

=item send_sms - Send SMS with activation code

=cut
sub send_sms {
    my ($activation_code, %info) = @_;
    my $logger = Log::Log4perl::get_logger('pf::sms_activation');

    my $smtpserver = $Config{'alerting'}{'smtpserver'};
    $info{'from'} = $Config{'alerting'}{'fromaddr'} || 'root@' . $fqdn;
    $info{'currentdate'} = POSIX::strftime( "%m/%d/%y %H:%M:%S", localtime );
    my ($hash_version, $pin) = _unpack_activation_code($activation_code);

    # Hash merge. Note that on key collisions the result of view_by_code() will win
    %info = (%info, %{view_by_code($activation_code)});

    # Strip non-digits
    my $phone = $info{'phone_number'};
    $phone =~ s/\D//g;
    my $email = sprintf($info{'carrier_email_pattern'}, $phone);
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
    };
    if ($@) {
      my $msg = "Can't send email to $email: $@";
      $msg =~ s/\n//g;
      $logger->error($msg);
    }
    
    return $result;
}

=item sms_activation_create_send - Create and send PIN code

=cut
sub sms_activation_create_send {
    my ($mac, $phone_number, $provider_id, %info) = @_;
    my $logger = Log::Log4perl::get_logger('pf::sms_activation');

    my ($success, $err) = ($TRUE, 0);
    my $activation_code = create($mac, $phone_number, $provider_id);
    if (defined($activation_code)) {
      unless (send_sms($activation_code, %info)) {
        ($success, $err) = ($FALSE, $GUEST::ERROR_CONFIRMATION_SMS);
      }
    }

    return ($success, $err);
}

# returns the validated mac address or undef
sub validate_code {
    my ($activation_code) = @_;
    my $logger = Log::Log4perl::get_logger('pf::sms_activation');

    my $activation_record = find_unverified_code($activation_code);
    if (!defined($activation_record) || ref($activation_record eq 'HASH')) {
        $logger->info("Unable to retrieve SMS activation entry based on activation code: $activation_code");
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
    $logger->info("Phone: ".$activation_record->{'phone_number'}." successfully verified! "
        . "Node authorized: ".$activation_record->{'mac'});
    return $activation_record->{'mac'};
}


=back

=head1 AUTHOR

Olivier Bilodeau <obilodeau@inverse.ca>

=head1 COPYRIGHT

Copyright (C) 2011 Inverse inc.

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
