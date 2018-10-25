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
use pf::util;
use pf::config::util qw();
use pf::Connection::ProfileFactory;
use pf::web::guest::constants;
use pf::web qw(i18n);
use pf::constants::Connection::Profile qw($DEFAULT_PROFILE);

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

=head2 Email activation types


=cut

Readonly our $SPONSOR_ACTIVATION => 'sponsor';
Readonly our $GUEST_ACTIVATION   => 'guest';
Readonly our $SMS_ACTIVATION     => 'sms';


BEGIN {
    use Exporter ();
    our ( @ISA, @EXPORT_OK );
    @ISA = qw(Exporter);

    @EXPORT_OK = qw(
        view_by_code
        $UNVERIFIED $EXPIRED $VERIFIED $INVALIDATED
        $SPONSOR_ACTIVATION $GUEST_ACTIVATION $SMS_ACTIVATION
    );
}

use pf::constants;
use pf::config qw(
    %Config
    $fqdn
);
use pf::file_paths qw($conf_dir $html_dir);
use pf::util;
use pf::web::constants;
# TODO this dependency is unfortunate, ideally it wouldn't be in that direction
use pf::log;
use pf::dal::activation;
use pf::error qw(is_error is_success);


=head1 SUBROUTINES

TODO: This list is incomplete

=cut

=head2 view

view a an pending activation record, returns an hashref

=cut

sub view {
    my ($code_id) = @_;
    my ($status, $item) = pf::dal::activation->find({code_id => $code_id});
    if (is_error($status)) {
        return undef;
    }
    return ($item->to_hash());
}

=head2 find_unverified_code

find an unused pending activation record by doing a LIKE in the code, returns an hashref

=cut

sub find_unverified_code {
    my ($type, $activation_code) = @_;
    my ($status, $iter) = pf::dal::activation->search(
        -where => {
            type => $type,
            activation_code => $activation_code,
            status => $UNVERIFIED,
            expiration => { ">=" => \['NOW()']}
        },
    );
    if (is_error($status)) {
        return undef;
    }
    my $item = $iter->next;
    if (!defined $item) {
        return undef;
    }
    return ($item->to_hash);
}

=head2 find_unverified_and_expired_code

find an unused and expired pending activation record by doing a LIKE in the code, returns an hashref

=cut

sub find_unverified_and_expired_code {
    my ($type, $activation_code) = @_;
    my ($status, $iter) = pf::dal::activation->search(
        -where => {
            type => $type,
            activation_code => $activation_code,
            status => $UNVERIFIED,
            expiration => { "<=" => \['NOW()']}
        },
    );
    if (is_error($status)) {
        return undef;
    }
    my $item = $iter->next;
    if (!defined $item) {
        return undef;
    }
    return ($item->to_hash);
}

=head2 view_by_code

view an pending  activation record by exact activation code (including hash format). Returns an hashref

=cut

sub view_by_code {
    my ($type, $activation_code) = @_;
    my ($status, $iter) = pf::dal::activation->search(
        -where => {
            type => $type,
            activation_code => $activation_code,
        },
        -no_auto_tenant_id => 1,
    );
    if (is_error($status)) {
        return undef;
    }
    my $item = $iter->next;
    if (!defined $item) {
        return undef;
    }
    return ($item->to_hash);
}

=head2 view_by_code_mac

view_by_code_mac

=cut

sub view_by_code_mac {
    my ($type, $code, $mac) = @_;
    my ($status, $iter) = pf::dal::activation->search(
        -where => {
            type => $type,
            activation_code => $code,
            mac => $mac,
        },
    );
    if (is_error($status)) {
        return undef;
    }
    my $item = $iter->next;
    if (!defined $item) {
        return undef;
    }
    return ($item->to_hash);
}

=head2 add

add an pending activation record to the database

=cut

sub add {
    my (%data) = @_;
    my $item = pf::dal::activation->new(\%data);
    return (is_success($item->insert));
}

=head2 _delete

delete an pending activation record

=cut

sub _delete {
    my ($code_id) = @_;
    my ($status, $rows) = pf::dal::activation->remove_by_id({code_id => $code_id});
    if (is_error($status)) {
        return undef;
    }
    return ($rows);
}

=head2 modify_status

update the status of a given pending activation record

=cut

sub modify_status {
    my ($code_id, $new_status) = @_;
    my ($status, $rows) = pf::dal::activation->update_items(
        -set => {
            status => $new_status,
        },
        -where => {
            code_id => $code_id,
        }
    );

    return $rows;
}

=head2 invalidate_codes

invalidate all unverified activation codes for a given mac and contact_info

=cut

sub invalidate_codes {
    my ($mac, $pid, $contact_info) = @_;
    my $logger = get_logger();
    my %args = (
        -set => {
            status => $INVALIDATED,
        },
        -where => {
            status => $UNVERIFIED,
            pid => $pid,
            contact_info => $contact_info,
            mac => $mac ? $mac : undef
        }
    );
    my ($status, $rows) = pf::dal::activation->update_items(%args);

    return $rows;
}

=head2 invalidate_codes_for_mac

invalidate codes for mac

=cut

sub invalidate_codes_for_mac {
    my ($mac, $type) = @_;
    my $logger = get_logger();
    unless ($mac) {
        return undef;
    }
    my ($status, $rows) = pf::dal::activation->update_items(
        -set => {
            status => $INVALIDATED
        },
        -where => {
            type => $type,
            mac => $mac,
            status => $UNVERIFIED
        }
    );
    return $rows;
}

=head2 create

create a new activation code

Returns the activation code

=cut

sub create {
    my ($args) = @_;
    my $mac          = $args->{'mac'};
    my $pid          = $args->{'pid'};
    my $pending_addr = $args->{'pending'};
    my $type         = $args->{'type'};
    my $portal       = $args->{'portal'};
    my $provider_id  = $args->{'provider_id'};
    my $timeout      = $args->{'timeout'};
    my $code_length  = $args->{'code_length'};
    my $no_unique    = $args->{'no_unique'};
    my $source_id    = $args->{'source_id'};

    my $logger = get_logger();

    unless($mac){
        $mac = undef;
    }

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
        'code_length' => $code_length,
        'no_unique' => $no_unique,
        'style'    => $args->{style},
        'source_id' => $source_id,
    );

    # caculate activation code expiration
    $data{'expiration'} = defined $timeout 
        ? POSIX::strftime("%Y-%m-%d %H:%M:%S", localtime(time + $timeout ))
        : POSIX::strftime("%Y-%m-%d %H:%M:%S", localtime(time + $EXPIRATION));


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
    my $code;
    my $code_length = $data{'code_length'} // 0;
    my $no_unique = $data{'no_unique'};
    my $type = $data{'type'};
    my $style = $data{'style'} // 'md5';
    do {
        # generating something not so easy to guess (and hopefully not in rainbowtables)
        if ($style eq 'digits') {
            $code = int(rand(9999999999)) + 1;
        } else {
            $code = md5_hex(
                join("|",
                    time + int(rand(10)),
                    grep {defined $_} @data{qw(expiration mac pid contact_info)})
            );
        }
        if ($code_length > 0) {
            $code = substr($code, 0, $code_length);
        }
        # make sure the generated code is unique
        $code = undef if (!$no_unique && view_by_code($type, $code));
    } while (!defined($code));

    return $code;
}

=head2 send_email

Send an email with the activation code

=cut

sub send_email {
    my ($type, $activation_code, $template, %info) = @_;
    my $logger = get_logger();
    my $profile = pf::Connection::ProfileFactory->_from_profile($info{portal}) // pf::Connection::ProfileFactory->_from_profile($DEFAULT_PROFILE);

    my $user_locale = clean_locale(setlocale(POSIX::LC_MESSAGES));
    if ($type eq $SPONSOR_ACTIVATION) {
        $logger->debug('We are doing sponsor activation', $user_locale);
        setlocale(POSIX::LC_MESSAGES, $Config{'advanced'}{'language'});
    }
    my $smtpserver = $Config{'alerting'}{'smtpserver'};
    $info{'from'} = $Config{'alerting'}{'fromaddr'} || 'root@' . $fqdn;
    $info{'currentdate'} = POSIX::strftime( "%m/%d/%y %H:%M:%S", localtime );
    $info{'subject'} = i18n($info{'subject'});

    if (defined($info{'activation_domain'})) {
        $info{'activation_uri'} = "https://". $info{'activation_domain'} . "$WEB::URL_EMAIL_ACTIVATION_LINK/$type/$activation_code";
    } else {
        $info{'activation_uri'} = "https://".$Config{'general'}{'hostname'}.".".$Config{'general'}{'domain'}
            ."$WEB::URL_EMAIL_ACTIVATION_LINK/$type/$activation_code";
    }
    # Hash merge. Note that on key collisions the result of view_by_code() will win
    %info = (%info, %{view_by_code($type, $activation_code)});
    
    my %TmplOptions = (
        INCLUDE_PATH    => [ map { $_ . "/emails/" } @{$profile->{_template_paths}} ],
    );

    utf8::decode($info{'subject'});
    my $result = pf::config::util::send_email($template, $info{'contact_info'}, $info{'subject'}, \%info, \%TmplOptions);
    setlocale(POSIX::LC_MESSAGES, $user_locale);
    return $result;
}

sub create_and_send_activation_code {
    my ($mac, $pid, $pending_addr, $template, $type, $portal, %info) = @_;

    my ($success, $err) = ($TRUE, 0);
    my %args = (
        mac     => $mac,
        pid     => $pid,
        pending => $pending_addr,
        type    => $type,
        portal  => $portal,
        timeout => $info{'activation_timeout'},
        source_id => $info{source_id},
    );

    $info{portal} = $portal;

    my $activation_code = create(\%args);
    if (defined($activation_code)) {
      unless (send_email($type, $activation_code, $template, %info)) {
        ($success, $err) = ($FALSE, $GUEST::ERROR_CONFIRMATION_EMAIL);
      }
    }

    return ($success, $err, $activation_code);
}

# returns the validated activation record hashref or undef
sub validate_code {
    my ($type, $activation_code) = @_;
    my $logger = get_logger();

    my $activation_record = find_unverified_code($type, $activation_code);
    if (!defined($activation_record) || ref($activation_record eq 'HASH')) {
        $logger->info("Unable to retrieve pending activation entry based on activation code: $activation_code");
        return;
    }

    # Force a solid match.
    my $code = $activation_record->{'activation_code'};
    if ($activation_code ne $code) {
        $logger->info("Activation code is not exactly the same as the one on record. $activation_code != $code");
        return;
    }

    # At this point, code is validated: return the activation record
    $logger->info( "["
          . ( $activation_record->{mac} ? $activation_record->{mac} : "unknown" )
          . "] Activation code sent to email $activation_record->{contact_info} from $activation_record->{pid} successfully verified.  for activation type: $activation_record->{type}"
    );
    return $activation_record;
}

=head2 validate_code_with_mac

validate_code_with_mac

=cut

sub validate_code_with_mac {
    my ($type, $activation_code, $mac) = @_;
    my $logger = get_logger();

    my $activation_record = find_unverified_code_by_mac($type, $activation_code, $mac);
    if (!defined($activation_record) || ref($activation_record eq 'HASH')) {
        $logger->info("Unable to retrieve pending activation entry based on activation code: $activation_code");
        return;
    }

    # Force a solid match.
    my $code = $activation_record->{'activation_code'};
    if ($activation_code ne $code) {
        $logger->info("Activation code is not exactly the same as the one on record. $activation_code != $code");
        return;
    }

    # At this point, code is validated: return the activation record
    $logger->info("[$activation_record->{mac}] Activation code sent to email $activation_record->{contact_info} from $activation_record->{pid} successfully verified. for activation type: $activation_record->{type}");
    return $activation_record;
}

=head2 find_unverified_code_by_mac

find_unverified_code_by_mac

=cut

sub find_unverified_code_by_mac {
    my ($type, $activation_code, $mac) = @_;
    my ($status, $iter) = pf::dal::activation->search(
        -where => {
            mac => $mac,
            type => $type,
            status => $UNVERIFIED,
            expiration => { ">=" => \['NOW()']},
            activation_code => $activation_code,
        },
    );
    if (is_error($status)) {
        return undef;
    }
    my $item = $iter->next;
    if (!defined $item) {
        return undef;
    }
    return ($item->to_hash);
}

=head2 is_expired

Test if the code expired

=cut

sub is_expired {
    my ($activation_code) = @_;
    my $logger = get_logger();

    my $activation_record = find_unverified_and_expired_code($activation_code);
    if (defined($activation_record)) {
        $logger->info("Expired pending activation found , activation code: $activation_code");
        return $TRUE;
    }
    return $FALSE;
}

=head2 set_status_verified

Change the status of a given pending activation code to VERIFIED which means it can't be used anymore.

=cut

sub set_status_verified {
    my ($type, $activation_code) = @_;
    my $logger = get_logger();

    my $activation_record = view_by_code($type, $activation_code);
    modify_status($activation_record->{'code_id'}, $VERIFIED);
}

=head2 set_status_verified_by_mac

Change the status of a given pending activation code to VERIFIED which means it can't be used anymore using the mac

=cut

sub set_status_verified_by_mac {
    my ($type, $activation_code, $mac) = @_;
    my $logger = get_logger();

    my $activation_record = view_by_code_mac($type, $activation_code, $mac);
    modify_status($activation_record->{'code_id'}, $VERIFIED);
}


sub activation_has_entry {
    my ($mac,$type) = @_;
    my ($status, $iter) = pf::dal::activation->search(
        -where => {
            mac => $mac,
            type => $type,
            status => $UNVERIFIED,
            expiration => { ">=" => \['NOW()']},
        },
        -columns => [\1],
        -limit => 1,
    );
    if (is_error($status)) {
        return undef;
    }
    my $items = $iter->all // [];
    return scalar @$items;
}

=head2 sms_activation_create_send

Create and send PIN code

=cut

sub sms_activation_create_send {
    my (%args) = @_;
    my $logger = get_logger();

    my ( $success, $err ) = ( $TRUE, 0 );
    my $activation_code = create(\%args);
    if (defined($activation_code)) {
        $args{'message'} =~ s/\$pin/$activation_code/;
        unless ($args{'source'}->sendActivationSMS($activation_code, $args{'mac'}, $args{'message'})) {
            ($success, $err) = ($FALSE, $GUEST::ERRORS{$GUEST::ERROR_CONFIRMATION_SMS});
            invalidate_codes($args{'mac'}, $args{'pid'}, $args{'pending'});
        }
    }

    return ($success, $err, $activation_code);
}

=head2 set_unregdate

Set the unregdate that should be assigned to the node once the activation record has been validated

=cut

sub set_unregdate {
    my ($type, $activation_code, $unregdate) = @_;
    get_logger->debug("Setting unregdate $unregdate for activation code $activation_code");
    my ($status, $rows) = pf::dal::activation->update_items(
        -set => {
            unregdate => $unregdate
        },
        -where => {
            type => $type,
            activation_code => $activation_code
        }
    );
    return $rows;
}

# TODO: add an expire / cleanup sub

=head1 AUTHOR

Inverse inc. <info@inverse.ca>

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

1;
