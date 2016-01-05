package pfconfig::backend::mysql;

=head1 NAME

pfconfig::backend::mysql

=cut

=head1 DESCRIPTION

pfconfig::backend::mysql

=cut

use strict;
use warnings;
use Sereal::Encoder;
use Sereal::Decoder;
use DBI;
use pfconfig::config;
use Try::Tiny;
use pfconfig::log;

use base 'pfconfig::backend';

sub init {

    # abstact
}

=head2 _get_db

Get a connection to the database

=cut

sub _get_db {
    my ($self) = @_;
    my $logger = pfconfig::log::get_logger;
    my $cfg    = pfconfig::config->new->section('mysql');
    my $db;
    eval {
        $db = DBI->connect( "DBI:mysql:database=$cfg->{db};host=$cfg->{host};port=$cfg->{port}",
            $cfg->{user}, $cfg->{pass}, { 'RaiseError' => 1 } );
    }; 
    if($@) {
        $logger->error("Caught error $@ while connecting to database.");
        return undef;
    }
    return $db;
}

=head2 _db_error

Handle a database error

=cut

sub _db_error {
    my ($self) = @_;
    my $logger = pfconfig::log::get_logger;
    $logger->error("Couldn't connect to MySQL database to access L2. This is a major problem ! Check the MySQL section in /usr/local/pf/conf/pfconfig.conf and make sure your database schema is up to date !");
}

=head2 get

Get an element by key

=cut

sub get {
    my ( $self, $key ) = @_;
    my $logger = pfconfig::log::get_logger;
    my $db = $self->_get_db();
    unless($db){ 
        $self->_db_error();
        return undef;
    }
    my $statement = $db->prepare( "SELECT value FROM keyed WHERE id=" . $db->quote($key) );
    eval {
        $statement->execute();
    };
    if($@){
        $logger->error("Couldn't select from table. Error : $@");
        return undef;
    }
    my $element;
    while ( my $row = $statement->fetchrow_hashref() ) {
        my $decoder = Sereal::Decoder->new;
        $element = $decoder->decode( $row->{value} );
    }
    $db->disconnect();
    return $element;
}

=head2 set

Set an element by key

=cut

sub set {
    my ( $self, $key, $value ) = @_;
    my $logger = pfconfig::log::get_logger;
    my $db = $self->_get_db();
    unless($db){ 
        $self->_db_error();
        return 0;
    }
    my $encoder = Sereal::Encoder->new;
    $value = $encoder->encode($value);
    my $result;
    eval {
        $result = $db->do( "REPLACE INTO keyed (id, value) VALUES(?,?)", undef, $key, $value );
    };
    if($@){
        $logger->error("Couldn't insert in table. Error : $@");
        return 0;
    }
    $db->disconnect();
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
    my $result = $db->do( "DELETE FROM keyed where id=?", undef, $key );
    $db->disconnect();
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
    my $result = $db->do( "DELETE FROM keyed" );
    $db->disconnect();
    return $result;
}

=head2 list

List keys in the backend

=cut

sub list {
    my ( $self ) = @_;
    my $logger = pfconfig::log::get_logger;
    my $db = $self->_get_db();
    unless($db){
        $self->_db_error();
        return 0;
    }
    my $statement = $db->prepare( "SELECT id FROM keyed");
    eval {
        $statement->execute();
    };
    if($@){
        $logger->error("Couldn't select from table. Error : $@");
        return undef;
    }
    my @keys = @{$statement->fetchall_arrayref()};
    @keys = map { $_->[0] } @keys;
    $db->disconnect();
    return @keys;
}

=head2 list_matching

List keys matching a regular expression

=cut

sub list_matching {
    my ( $self, $expression ) = @_;
    my $logger = pfconfig::log::get_logger;
    my $db = $self->_get_db();
    unless($db){
        $self->_db_error();
        return 0;
    }
    my $statement = $db->prepare( "SELECT id FROM keyed where id regexp ".$db->quote($expression) );
    eval {
        $statement->execute();
    };
    if($@){
        $logger->error("Couldn't select from table. Error : $@");
        return undef;
    }
    my @keys = @{$statement->fetchall_arrayref()};
    @keys = map { $_->[0] } @keys;
    $db->disconnect();
    return @keys;
}

=back

=head1 AUTHOR

Inverse inc. <info@inverse.ca>

=head1 COPYRIGHT

Copyright (C) 2005-2015 Inverse inc.

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

