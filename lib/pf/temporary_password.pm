package pf::temporary_password;

=head1 NAME

pf::temporary_password - module to view, query and manage temporary passwords

=cut

=head1 DESCRIPTION

pf::temporary_password contains the functions necessary to manage all aspects
of temporary passwords: creation, deletion, etc.
utility methods generate activation codes and validate them.

=head1 DEVELOPER NOTES

Notice that this module doesn't export all its subs like our other modules do.
This is an attempt to shift our paradigm towards calling with package names 
and avoid the double naming. 

For ex: pf::temporary_password::view() instead of 
pf::temporary_password::temporary_password_view()

Remove this note when it will be no longer relevant. ;)

=head1 BUGS AND LIMITATIONS

If you keep getting the same passwords over and over again make sure that you've got
  PerlChildInitHandler "sub { srand }"
in your apache config.

=cut
#TODO rename to temporary_credentials to better reflect what this is about
#TODO properly hash passwords (1000 SHA1 iterations of salt + password)
use strict;
use warnings;

use Crypt::GeneratePassword qw(word);
use Log::Log4perl;
use POSIX;
use Readonly;

our $VERSION = 1.10;

# Constants
use constant TEMPORARY_PASSWORD => 'temporary_password';

# Authenticatation return codes
Readonly our $AUTH_SUCCESS => 0;
Readonly our $AUTH_FAILED_INVALID => 1;
Readonly our $AUTH_FAILED_EXPIRED => 2;
Readonly our $AUTH_FAILED_NOT_YET_VALID => 3;

# Expiration time in seconds
Readonly::Scalar our $EXPIRATION => 31*24*60*60; # defaults to 31 days

BEGIN {
    use Exporter ();
    our ( @ISA, @EXPORT, @EXPORT_OK );
    @ISA = qw(Exporter);
    @EXPORT = qw(
        temporary_password_db_prepare
        $temporary_password_db_prepared
    );

    @EXPORT_OK = qw(
        view add modify 
        create
        validate_password
        $AUTH_SUCCESS $AUTH_FAILED_INVALID $AUTH_FAILED_EXPIRED $AUTH_FAILED_NOT_YET_VALID
    );
}

use pf::config;
use pf::db;
use pf::util;

# The next two variables and the _prepare sub are required for database handling magic (see pf::db)
our $temporary_password_db_prepared = 0;
# in this hash reference we hold the database statements. We pass it to the query handler and he will repopulate
# the hash if required
our $temporary_password_statements = {};

=head1 SUBROUTINES

TODO: This list is incomlete

=over

=cut

sub temporary_password_db_prepare {
    my $logger = Log::Log4perl::get_logger('pf::temporary_password');
    $logger->debug("Preparing pf::temporary_password database queries");

    $temporary_password_statements->{'temporary_password_view_sql'} = get_db_handle()->prepare(qq[
        SELECT pid, password, valid_from, expiration, access_duration, category
        FROM temporary_password 
        WHERE pid = ?
    ]);

    $temporary_password_statements->{'temporary_password_add_sql'} = get_db_handle()->prepare(qq[
        INSERT INTO temporary_password
            (pid, password, valid_from, expiration, access_duration, category)
        VALUES (?, ?, ?, ?, ?, ?)
    ]);

    $temporary_password_statements->{'temporary_password_delete_sql'} = get_db_handle()->prepare(
        qq [ DELETE FROM temporary_password WHERE pid = ? ]
    );

    $temporary_password_statements->{'temporary_password_validate_password_sql'} = get_db_handle()->prepare(qq[ 
        SELECT pid, password, UNIX_TIMESTAMP(valid_from) as valid_from, UNIX_TIMESTAMP(expiration) as expiration,
            access_duration, category
        FROM temporary_password
        WHERE pid = ?
        ORDER BY expiration DESC
        LIMIT 1
    ]);

    $temporary_password_db_prepared = 1;
}

=item view 

view a a temporary password record, returns an hashref

=cut
sub view {
    my ($pid) = @_;
    my $query = db_query_execute(
        TEMPORARY_PASSWORD, $temporary_password_statements, 'temporary_password_view_sql', $pid
    );
    my $ref = $query->fetchrow_hashref();

    # just get one row and finish
    $query->finish();
    return ($ref);
}

=item add 

add a temporary password record to the database

=cut
#sub add {
#    my (%data) = @_;
#
#    return(db_data(TEMPORARY_PASSWORD, $temporary_password_statements, 
#        'temporary_password_add_sql', 
#        $data{'pid'}, $data{'password'}, $data{'valid_from'}, $data{'expiration'}, $data{'access_duration'}
#    ));
#}

=item _delete

_delete a temporary password record

=cut
sub _delete {
    my ($pid) = @_;

    return(db_query_execute(
        TEMPORARY_PASSWORD, $temporary_password_statements, 'temporary_password_delete_sql', $pid
    ));
}

=item create 

Creates a temporary password record for a given pid. Valid until given expiration.

=cut
sub create {
    my (%data) = @_;

    return(db_data(TEMPORARY_PASSWORD, $temporary_password_statements,
        'temporary_password_add_sql',
        $data{'pid'}, $data{'password'}, $data{'valid_from'}, $data{'expiration'}, $data{'access_duration'}, $data{'category'}
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
    my ($pid, $expiration, $valid_from, $access_duration, $category, $password) = @_;
    my $logger = Log::Log4perl::get_logger('pf::temporary_password');

    my %data;
    $data{'pid'} = $pid;

    # if $expiration is set we use it, otherwise we use the module default
    $data{'expiration'} = $expiration || POSIX::strftime("%Y-%m-%d %H:%M:%S", localtime(time + $EXPIRATION));

    # if $valid_from is set we use it, otherwise set to null which means valid from the begining of time
    $data{'valid_from'} = $valid_from || undef;

    # if $access_duration is set we use it, otherwise set to null which means don't use per user duration
    $data{'access_duration'} = $access_duration || undef;

    # generate password 
    $data{'password'} = $password || _generate_password();

    # category
    $data{'category'} = $category || undef;

    # if an entry of the same pid already exist, delete it
    if (defined(view($pid))) {
        $logger->info("a new temporary account has been requested for $pid. Deleting previous entry");
        _delete($pid);
    }

    my $result = create(%data);
    if (defined($result)) {
        $logger->info("new temporary account successfully generated");
        return $data{'password'};
    } else {
        $logger->warn("something went wrong creating a new temporary password for $pid");
        return;
    }
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
    my ($pid, $password) = @_;

    my $query = db_query_execute(
        TEMPORARY_PASSWORD, $temporary_password_statements,
        'temporary_password_validate_password_sql', $pid
    );

    my $temppass_record = $query->fetchrow_hashref();
    # just get one row
    $query->finish();
    
    if (!defined($temppass_record) || ref($temppass_record) ne 'HASH') {
        return $AUTH_FAILED_INVALID;
    }

    # password is valid but not yet valid
    # valid_from is in unix timestamp format so an int comparison is enough
    if ($temppass_record->{'password'} eq $password && $temppass_record->{'valid_from'} > time) {
        return $AUTH_FAILED_NOT_YET_VALID;
    }   

    # password is valid but expired
    # expiration is in unix timestamp format so an int comparison is enough
    if ($temppass_record->{'password'} eq $password && $temppass_record->{'expiration'} < time) {
        return $AUTH_FAILED_EXPIRED;
    }   

    # password match success
    if ($temppass_record->{'password'} eq $password) {
        return ( $AUTH_SUCCESS, $temppass_record->{'access_duration'}, $temppass_record->{'category'});
    }

    # otherwise failure
    return $AUTH_FAILED_INVALID;
}

=back

=head1 AUTHOR

Olivier Bilodeau <obilodeau@inverse.ca>

=head1 COPYRIGHT

Copyright (C) 2010,2011 Inverse inc.

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
