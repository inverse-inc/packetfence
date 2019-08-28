package pfconfig::backend::mysql;

=head1 NAME

pfconfig::backend::mysql

=cut

=head1 DESCRIPTION

pfconfig::backend::mysql

=cut

use strict;
use warnings;
use Sereal::Encoder qw(sereal_encode_with_object);
use Sereal::Decoder qw(sereal_decode_with_object);
use DBI;
use pfconfig::config;
use Try::Tiny;
use pf::log;
use pf::Sereal qw($DECODER $ENCODER);

use base 'pfconfig::backend';

sub init {
    my ($self) = @_;
    $self->{should_clear} = 0;
}

=head2 _get_db

Get a connection to the database

=cut

sub _get_db {
    my ($self) = @_;
    return $self->{_db} if (defined $self->{_db} && $self->{_db}->ping);
    my $logger = get_logger;
    $logger->info("Connecting to MySQL database");
    
    my $cfg    = pfconfig::config->new->section('mysql');
    my $db;
    eval {
        $db = DBI->connect( "DBI:mysql:database=$cfg->{db};host=$cfg->{host};port=$cfg->{port}",
            $cfg->{user}, $cfg->{pass}, { 'RaiseError' => 1, mysql_auto_reconnect => 1 } );
    };
    if($@) {
        $logger->error("Caught error $@ while connecting to database.");
        return undef;
    }
    $self->{_db} = $db;
    $self->{_table} = $cfg->{table};
    return $db;
}

=head2 db_readonly_mode

Whether or not the database is in read only mode
In which case, we should not read from it since it can't be updated

=cut

sub db_readonly_mode {
    my ($self) = @_;

    my $logger = get_logger;

    my $dbh = $self->{_db} || $self->_get_db();
    my $sth = $dbh->prepare_cached('SELECT @@global.read_only;');

    my $result;
    eval {
        $sth->execute;
        my $row = $sth->fetch;
        $sth->finish;
        $result = $row->[0];
    };
    if($@) {
        $logger->error("Cannot connect to database to see if its in read-only mode. Will consider it in read-only.");
        return 1;
    }
    # If readonly no need to check wsrep health
    return 1 if $result;
    # If wsrep is not healthly then it is in readonly mode
    return !$self->db_wsrep_healthy();
}

sub db_wsrep_healthy {
    my ($self) = @_;

    my $logger = get_logger();
    my $dbh = $self->{_db} || $self->_get_db();
    return 0 unless $dbh;

    my $sth = $dbh->prepare_cached('show status like "wsrep_provider_name";');
    return 0 unless $sth->execute;
    my $row = $sth->fetch;
    $sth->finish;

    if(defined($row) && $row->[1] ne "") {
        $logger->debug("There is a wsrep provider, checking the wsrep_ready flag");
        # check if the wsrep_ready status is ON
        $sth = $dbh->prepare_cached('show status like "wsrep_ready";');
        return 0 unless $sth->execute;
        $row = $sth->fetch;
        $sth->finish;
        # If there is no wsrep_ready row, then we're not in read only because we don't use wsrep
        # If its there and not set to ON, then we're in read only
        return (defined($row) && $row->[1] eq "ON");
    }
    # wsrep isn't enabled
    else {
        $logger->debug("No wsrep provider so considering wsrep as healthy");
        return 1;
    }
}


=head2 _db_error

Handle a database error

=cut

sub _db_error {
    my ($self) = @_;
    my $logger = get_logger;
    $logger->error("Couldn't connect to MySQL database to access L2. This is a major problem ! Check the MySQL section in /usr/local/pf/conf/pfconfig.conf and make sure your database schema is up to date !");
}

=head2 get

Get an element by key

=cut

sub get {
    my ( $self, $key ) = @_;
    my $logger = get_logger;
    my $db = $self->_get_db();
    unless($db){
        $self->_db_error();
        return undef;
    }

    if($self->db_readonly_mode) {
        $logger->error("Not gathering data from backend since its in read-only mode.");
        # Signal that we should clear the backend when we recover a read/write connection
        # This is done since outside of this backend, the process could load a different version of what is in the DB which will cause issues when we go out of read-only
        $self->{should_clear} = 1;
        return undef;
    }
    elsif($self->{should_clear}) {
        $logger->info("Signaled to clear the backend. Clearing now.");
        $self->{should_clear} = 0;
        $self->clear();
    }

    my $statement = $db->prepare( "SELECT value FROM $self->{_table} WHERE id=" . $db->quote($key) );
    eval {
        $statement->execute();
    };
    if($@){
        $logger->error("Couldn't select from table. Error : $@");
        return undef;
    }
    my $element;
    while ( my $row = $statement->fetchrow_hashref() ) {
        $element = sereal_decode_with_object($DECODER, $row->{value});
    }
    return $element;
}

=head2 set

Set an element by key

=cut

sub set {
    my ( $self, $key, $value ) = @_;
    my $logger = get_logger;
    my $db = $self->_get_db();
    unless($db){
        $self->_db_error();
        return 0;
    }
    $value = sereal_encode_with_object($ENCODER, $value);
    my $result;
    eval {
        $result = $db->do( "REPLACE INTO $self->{_table} (id, value) VALUES(?,?)", undef, $key, $value );
    };
    if($@){
        $logger->error("Couldn't insert in table. Error : $@");
        return 0;
    }
    return $result;
}

=head2 remove

Remove an element by key

=cut

sub remove {
    my ( $self, $key ) = @_;
    my $db = $self->_get_db();
    unless($db){
        $self->_db_error();
        return 0;
    }
    my $result = $db->do( "DELETE FROM $self->{_table} where id=?", undef, $key );
    return $result;
}

=head2 clear

Clear out the backend

=cut

sub clear {
    my ( $self ) = @_;
    my $db = $self->_get_db();
    unless($db){
        $self->_db_error();
        return 0;
    }
    my $result = $db->do( "DELETE FROM $self->{_table}" );
    return $result;
}

=head2 list

List keys in the backend

=cut

sub list {
    my ( $self ) = @_;
    my $logger = get_logger;
    my $db = $self->_get_db();
    unless($db){
        $self->_db_error();
        return ();
    }
    
    my $statement = $db->prepare( "SELECT id FROM $self->{_table}");
    eval {
        $statement->execute();
    };
    if($@){
        $logger->error("Couldn't select from table. Error : $@");
        return undef;
    }
    my @keys = @{$statement->fetchall_arrayref()};
    @keys = map { $_->[0] } @keys;
    return @keys;
}

=head2 list_matching

List keys matching a regular expression

=cut

sub list_matching {
    my ( $self, $expression ) = @_;
    my $logger = get_logger;
    my $db = $self->_get_db();
    unless($db){
        $self->_db_error();
        return ();
    }

    my $statement = $db->prepare( "SELECT id FROM $self->{_table} where id regexp ".$db->quote($expression) );
    eval {
        $statement->execute();
    };
    if($@){
        $logger->error("Couldn't select from table. Error : $@");
        return undef;
    }
    my @keys = @{$statement->fetchall_arrayref()};
    @keys = map { $_->[0] } @keys;
    return @keys;
}

sub reset {
    my ($self) = @_;
    my $db = $self->{_db};
    return unless defined $db;
    $db->disconnect();
    delete $self->{_db};
}

=head1 AUTHOR

Inverse inc. <info@inverse.ca>

=head1 COPYRIGHT

Copyright (C) 2005-2019 Inverse inc.

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

# vim: set shiftwidth=4:
# vim: set expandtab:
# vim: set backspace=indent,eol,start:

