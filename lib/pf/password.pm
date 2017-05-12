package pf::password;

=head1 NAME

pf::password - module to view, query and manage temporary passwords

=head1 DESCRIPTION

pf::password contains the functions necessary to manage all aspects
of temporary passwords: creation, deletion, etc.
utility methods generate activation codes and validate them.

=head1 DEVELOPER NOTES

Notice that this module doesn't export all its subs like our other modules do.
This is an attempt to shift our paradigm towards calling with package names
and avoid the double naming.

For ex: pf::password::view() instead of
pf::password::password_view()

Remove this note when it will be no longer relevant. ;)

=head1 BUGS AND LIMITATIONS

If you keep getting the same passwords over and over again make sure that you've got
  PerlChildInitHandler "sub { srand }"
in your apache config.

=cut

use strict;
use warnings;

use Date::Parse;
use Crypt::GeneratePassword qw(word);
use Crypt::SmbHash qw(nthash);
use pf::log;
use POSIX;
use Readonly;

use pf::nodecategory;
use pf::Authentication::constants;
use Crypt::Eksblowfish::Bcrypt qw(bcrypt_hash en_base64 de_base64 );
use Bytes::Random::Secure;


# Constants
use constant PASSWORD => 'password';


# Authenticatation return codes
Readonly our $AUTH_SUCCESS              => 0;
Readonly our $AUTH_FAILED_INVALID       => 1;
Readonly our $AUTH_FAILED_EXPIRED       => 2;
Readonly our $AUTH_FAILED_NOT_YET_VALID => 3;
Readonly our $PLAINTEXT                 => 'plaintext';
Readonly our $BCRYPT                    => 'bcrypt';
Readonly our $NTLM                      => 'ntlm';

# Expiration time in seconds
Readonly::Scalar our $EXPIRATION => 31*24*60*60; # defaults to 31 days

BEGIN {
    use Exporter ();
    our ( @ISA, @EXPORT_OK );
    @ISA    = qw(Exporter);
    @EXPORT_OK = qw(
        $AUTH_SUCCESS $AUTH_FAILED_INVALID $AUTH_FAILED_EXPIRED $AUTH_FAILED_NOT_YET_VALID $BCRYPT $PLAINTEXT $NTLM
    );
}

use pf::constants;
use pf::config qw(%Config);
use pf::db;
use pf::util;

# The next two variables and the _prepare sub are required for database handling magic (see pf::db)
our $password_db_prepared = 0;
# in this hash reference we hold the database statements. We pass it to the query handler and he will repopulate
# the hash if required
our $password_statements = {};

=head1 SUBROUTINES

TODO: This list is incomlete

=over


=item password_db_prepare

Instantiate SQL statements to be prepared

=cut

sub password_db_prepare {
    my $logger = get_logger();
    $logger->debug("Preparing pf::password database queries");

    $password_statements->{'password_view_sql'} = get_db_handle()->prepare(qq[
        SELECT t.pid, t.password, t.valid_from, t.expiration, t.access_duration, t.access_level, c.name as category, t.sponsor, t.unregdate, t.login_remaining,
            p.firstname, p.lastname, p.email, p.telephone, p.company, p.address, p.notes
        FROM password t
        LEFT JOIN person p ON t.pid = p.pid
        LEFT JOIN node_category c ON t.category = c.category_id
        WHERE t.pid = ?
    ]);

    $password_statements->{'password_view_email_sql'} = get_db_handle()->prepare(qq[
        SELECT t.pid, t.password, t.valid_from, t.expiration, t.access_duration, t.access_level, c.name as category, t.sponsor, t.unregdate, t.login_remaining,
            p.firstname, p.lastname, p.email, p.telephone, p.company, p.address, p.notes
        FROM person p, password t
        LEFT JOIN node_category c ON t.category = c.category_id
        WHERE t.pid = p.pid AND p.email = ?
    ]);

    $password_statements->{'password_add_sql'} = get_db_handle()->prepare(qq[
        INSERT INTO password
            (pid, password, valid_from, expiration, access_duration, access_level, category, sponsor, unregdate, login_remaining)
        VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
    ]);

    $password_statements->{'password_delete_sql'} = get_db_handle()->prepare(
        qq [ DELETE FROM password WHERE pid = ? ]
    );

    $password_statements->{'password_validate_password_sql'} = get_db_handle()->prepare(qq[
        SELECT pid, password, UNIX_TIMESTAMP(valid_from) as valid_from,
            UNIX_TIMESTAMP(DATE_FORMAT(expiration,"%Y-%m-%d 23:59:59")) AS expiration,
            access_duration, category
        FROM password
        WHERE pid = ?
        ORDER BY expiration DESC
        LIMIT 1
    ]);

    $password_statements->{'password_modify_actions_sql'} = get_db_handle()->prepare(qq[
        UPDATE password
        SET valid_from = ?, expiration = ?, access_duration = ?, access_level = ?, category = ?, sponsor = ?, unregdate = ?
        WHERE pid = ?
    ]);

    $password_statements->{'password_reset_password_sql'} = get_db_handle()->prepare(qq[
        UPDATE password SET password = ? WHERE pid = ?
    ]);

    $password_statements->{'password_consume_login_sql'} = get_db_handle()->prepare(qq[
        UPDATE password SET login_remaining = login_remaining - 1 WHERE pid = ? and login_remaining > 0
    ]);

    $password_db_prepared = 1;
}

=item view

view a temporary password record, returns an hashref

=cut

sub view {
    my ($pid) = @_;
    my $query = db_query_execute(
        PASSWORD, $password_statements, 'password_view_sql', $pid
    ) || return;
    my $ref = $query->fetchrow_hashref();

    # just get one row and finish
    $query->finish();
    return ($ref);
}

=item view_email

view the temporary password record associated to an email address, returns an hashref

=cut

sub view_email {
    my ($email) = @_;
    my $query = db_query_execute(
        PASSWORD, $password_statements, 'password_view_email_sql', $email
    ) || return;
    my $ref = $query->fetchrow_hashref();

    # just get one row and finish
    $query->finish();
    return ($ref);
}


=item _delete

_delete a temporary password record

=cut

sub _delete {
    my ($pid) = @_;

    return(db_query_execute(
        PASSWORD, $password_statements, 'password_delete_sql', $pid
    ));
}

=item create

Creates a temporary password record for a given pid. Valid until given expiration.

=cut

sub create {
    my (%data) = @_;

    return(db_data(PASSWORD, $password_statements,
        'password_add_sql',
        $data{'pid'}, $data{'password'}, $data{'valid_from'}, $data{'expiration'}, $data{'access_duration'}, $data{'access_level'}, $data{'category'}, $data{'sponsor'}, $data{'unregdate'}, $data{'login_remaining'}
    ));
}

=item _generate_password

Generates the password

=cut

sub _generate_password {

    my $password = word(8, 12);
    # if password is nasty generate another one (until we get a clean one)
    while(Crypt::GeneratePassword::restrict($password, undef)) {
        $password = word(8, 12);
    }
    return $password;
}

=item generate

Generates a temporary password and add it to the temporary password table.

Returns the temporary password

Optional arguments:

=over

=item expiration date

Credentials won't work after expiration date

Defaults to module's default (31 days)

=item valid from date

Credentials won't work before valid_from date

Defaults to 0 (works now)

=item acess duration

On login, how long should this user has access?

Defaults to 0 (no per user limit)

=back

=cut

sub generate {
    my ( $pid, $actions, $password, $login_amount ) = @_;
    my $logger = get_logger();

    my %data;
    $data{'pid'} = $pid;
    $password ||= _generate_password();

    # hash password
    $data{'password'} = _hash_password( $password, algorithm => $Config{'advanced'}{'hash_passwords'}, );

    $data{'login_remaining'} = $login_amount;

    _update_from_actions( \%data, $actions );

    # if an entry of the same pid already exist, delete it
    if ( defined( view($pid) ) ) {
        $logger->info("a new temporary account has been requested for $pid. Deleting previous entry");
        _delete($pid);
    }

    my @result = create(%data);
    if ( scalar @result == 1 && $result[0] == 0 ) {
        $logger->warn("something went wrong creating a new temporary password for $pid");
        return;
    }
    else {
        $logger->info("new temporary account successfully generated");
        return $password;
    }
}

=item _update_from_actions

Updates password fields from an action list

=cut

sub _update_from_actions {
    my ($data, $actions) = @_;

    _update_field_for_action(
        $data,$actions,'valid_from',
        'valid_from', '0000-00-00 00:00:00'
    );
    _update_field_for_action(
        $data,$actions,'expiration',
        'expiration',POSIX::strftime("%Y-%m-%d %H:%M:%S", localtime(time + $EXPIRATION))
    );
    _update_field_for_action(
        $data,$actions,$Actions::MARK_AS_SPONSOR,
        'sponsor',0
    );
    _update_field_for_action(
        $data,$actions,$Actions::SET_ACCESS_LEVEL,
        'access_level','NONE'
    );
    _update_field_for_action(
        $data,$actions,$Actions::SET_UNREG_DATE,
        'unregdate',"0000-00-00 00:00:00"
    );
    _update_field_for_action(
        $data,$actions,$Actions::SET_ACCESS_DURATION,
        'access_duration',undef
    );
    _update_field_for_action(
        $data,$actions,$Actions::SET_TIME_BALANCE,
        'time_balance',undef
    );
    _update_field_for_action(
        $data,$actions,$Actions::SET_BANDWIDTH_BALANCE,
        'bandwidth_balance',undef
    );
    my @values = grep { $_->{type} eq $Actions::SET_ROLE } @{$actions};
    if (scalar @values > 0) {
        my $role_id = nodecategory_lookup( $values[0]->{value} );
        $data->{'category'} = $role_id;
    }
}

=item _update_field_for_action

Updates password field from an action

=cut

sub _update_field_for_action {
    my ( $data, $actions, $action, $field, $default ) = @_;
    my @values = grep { $_->{type} eq $action } @{$actions};
    if ( scalar @values > 0 ) {
        $data->{$field} = $values[0]->{value};
    }
    else {
        $data->{$field} = $default;
    }
}

=item modify_actions

Modify the password actions

=cut

sub modify_actions {
    my ( $password, $actions ) = @_;
    my $logger        = get_logger();
    my @ACTION_FIELDS = qw(
        valid_from expiration
        access_duration access_level category sponsor unregdate
        );    # respect the prepared statement placeholders order
    delete @{$password}{@ACTION_FIELDS};
    _update_from_actions( $password, $actions );
    my $pid   = $password->{pid};
    my $query = db_query_execute(
        PASSWORD,
        $password_statements,
        'password_modify_actions_sql',
        @{$password}{@ACTION_FIELDS}, $pid
    );
    my $rows = $query->rows;
    $logger->info("pid $pid modified") if $rows;
    return ($rows);
}


=item validate_password

Validate password for a given pid.

Return values:
 $AUTH_SUCCESS, access_duration - success
 $AUTH_FAILED_INVALID - invalid user/pass
 $AUTH_FAILED_EXPIRED - password expired
 $AUTH_FAILED_NOT_YET_VALID - password not valid yet

=cut

sub validate_password {
    my ( $pid, $password ) = @_;

    my $logger = get_logger();

    my $query = db_query_execute(
        PASSWORD,
        $password_statements,
        'password_validate_password_sql', $pid
    );

    my $temppass_record = $query->fetchrow_hashref();

    # just get one row
    $query->finish();

    if ( !defined($temppass_record) || ref($temppass_record) ne 'HASH' ) {
        return $AUTH_FAILED_INVALID;
    }

    if ( _check_password( $password, $temppass_record->{'password'}) ) {

        # password is valid but not yet valid
        # valid_from is in unix timestamp format so an int comparison is enough
        my $valid_from = $temppass_record->{'valid_from'};
        if ( defined $valid_from && $valid_from > time ) {
            $logger->info("Password validation failed for $pid: password not yet valid");
            return $AUTH_FAILED_NOT_YET_VALID;
        }

        # password is valid but expired
        # expiration is in unix timestamp format so an int comparison is enough
        if ( $temppass_record->{'expiration'} < time ) {
            $logger->info("Password validation failed for $pid: password has expired");
            return $AUTH_FAILED_EXPIRED;
        }

        # password match success
        return $AUTH_SUCCESS;
    }

    # otherwise failure
    $logger->info("Password validation failed for $pid: passwords don't match");
    return $AUTH_FAILED_INVALID;
}

sub _check_password {
    my ( $plaintext, $hash_string ) = @_;

    # the algorithm is contained in the prefix of the password such as
    # {md5}, {bcrypt} etc.
    # Plaintext passwords have no prefix.
    # We need to quotemeta the regex because it contains { and }
    my $bcrypt_re = quotemeta('{bcrypt}');
    my $ntlm_re = quotemeta('{ntlm}');
    if ($hash_string =~ /^$bcrypt_re/) {
        return _check_bcrypt(@_);
    } elsif ($hash_string =~ /^$ntlm_re/) {
        return _check_ntlm(@_);
    } else {
        # I am leaving room for additional cases (NT hashes, md5 etc.)
        return $plaintext eq $hash_string ? $TRUE : $FALSE;
    }
}

=item password_get_hash_type

extract the type of hash for the password

=cut

sub password_get_hash_type {
    my ($passwd) = @_;
    my $type  = 'plaintext';
    if ($passwd =~ /^\{([^{}]*)\}/ ) {
        $type = $1;
    }
    return $type;
}

sub _hash_password {
    my ($plaintext, %params) = @_;
    my $logger = pf::log::get_logger;
    my $algorithm = $params{"algorithm"};
    if ($algorithm =~ /$PLAINTEXT/) {
        return $plaintext;
    } elsif ($algorithm =~ /$BCRYPT/) {
        return bcrypt($plaintext, %params);
    } elsif ($algorithm =~ /$NTLM/) {
        return '{ntlm}'.nthash($plaintext);
    } else {
        $logger->error("Unsupported hash algorithm " . $params{"algorithm"});
    }
}

sub _check_bcrypt {
    my ( $plaintext, $hash_string ) = @_;
    my ( $cost, $salt, $hash_value, $hashed_plaintext );

    # Bcrypt is special. We need to parse the hash to know the work factor before comparing.
    # A bcrypt hash looks like this:
    # '$2a$05$1kdrBExRmcKCcDlNSKHREutpl02jsbx7.ug5C3SZ86N1QhqUF.aSW'
    # where '$2a$' is the bcrypt prefix, 05 is the work factor, and the rest (after the final $)
    # is the bcrypt base64 encoded salt (first 22 char) followed by the bcrypt base64 encoded hash value.
    my $prefix_len        = 12;
    my $cost_len          = 2;
    my $salt_len          = 22;
    my $before_salt       = $prefix_len + $cost_len + 1;    # +1 for the trailing $
    my $before_hash_value = $before_salt + $salt_len;
    $cost = substr( $hash_string, $prefix_len,  $cost_len );
    $salt = substr( $hash_string, $before_salt, $salt_len );
    $hash_value = substr( $hash_string, $before_hash_value );    # substr to the end of the string

    $hashed_plaintext = _hash_password( $plaintext, algorithm => $BCRYPT, salt => $salt, cost => $cost );

    if ( $hashed_plaintext eq $hash_string ) {
        return $TRUE;
    }
    else {
        return $FALSE;
    }
}

sub bcrypt {
    my ( $plaintext, %params ) = @_;

    my $random = Bytes::Random::Secure->new(
        Bits        => 64,
        NonBlocking => 1,
    );
    my $bytes = $random->bytes(16); # blowfish requires 16 octets

    my $salt
        = $params{"salt"} ? de_base64( $params{"salt"} ) : $bytes;
    my $cost = $params{"cost"} // $Config{'advanced'}{'hashing_cost'}
        // 8;    # TODO: remove fallback once tests work

    # A bcrypt hash looks like this:
    # '$2a$05$1kdrBExRmcKCcDlNSKHREutpl02jsbx7.ug5C3SZ86N1QhqUF.aSW'
    # where '$2a$' is the bcrypt prefix, 05 is the work factor, and the rest (after the final $)
    # is the bcrypt base64 encoded salt (first 22 char) followed by the bcrypt base64 encoded hash value.
    my $hash     = bcrypt_hash( { key_nul => 1, cost => $cost, salt => $salt, }, $plaintext );
    my $hash_str = en_base64($hash);
    my $cost_str = sprintf( "%02d", $cost ) . '$';
    my $salt_str = en_base64($salt);
    return '{bcrypt}' . '$2a$' . $cost_str . $salt_str . $hash_str;
}

sub _check_ntlm {
    my ( $plaintext, $hash_string ) = @_;

    my $hashed_plaintext = '{ntlm}'.nthash($plaintext);

    if ( $hashed_plaintext eq $hash_string ) {
        return $TRUE;
    }
    else {
        return $FALSE;
    }
}

=item reset_password

Reset (change) a password for a user in the password table.

=cut

sub reset_password {
    my ( $pid, $password ) = @_;
    my $logger = get_logger();

    # Making sure pid/password are "ok"
    if ( !defined($pid) || !defined($password) || (length($pid) == 0) || (length($password) == 0) ) {
        $logger->error("Error while resetting the user password. Missing values.");
        return undef;
    }

    # hash the password if required
    if ( $Config{'advanced'}{'hash_passwords'} ne $PLAINTEXT ) {
        $password = _hash_password( $password, ( algorithm => $Config{'advanced'}{'hash_passwords'} ));
    }

    db_query_execute(
        PASSWORD, $password_statements, 'password_reset_password_sql', $password, $pid
    ) || return undef;
}

=item consume_login

Consume a login for the password entry

Returns true if the password entry can still be used for login

=cut

sub consume_login {
    my ($pid) = @_;
    my $user = view($pid);
    # if the remaining login amount is undef, this means that the user is allowed unlimited logins
    # Otherwise, the user can use the amount of login in the column
    # When the amount remaining is at 0, this returns false
    if(defined($user->{login_remaining})){
        if($user->{login_remaining} > 0){
            db_query_execute(
                PASSWORD, $password_statements, 'password_consume_login_sql', $pid
            ) || return $FALSE;
            return $TRUE;
        }
        else {
            return $FALSE;
        }
    }
    else {
        return $TRUE;
    }
}

=back

=head1 AUTHOR

Inverse inc. <info@inverse.ca>

=head1 COPYRIGHT

Copyright (C) 2005-2017 Inverse inc.

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
