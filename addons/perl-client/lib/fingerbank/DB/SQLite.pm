package fingerbank::DB::SQLite;

=head1 NAME

fingerbank::DB

=head1 DESCRIPTION

Databases related interaction class

=cut

use Moose;

extends 'fingerbank::DB';

use File::Copy qw(copy move);
use JSON;
use POSIX qw(strftime);

use fingerbank::Config;
use fingerbank::Constant qw($TRUE $FALSE $LOCAL_SCHEMA $UPSTREAM_SCHEMA);
use fingerbank::FilePath qw($INSTALL_PATH $LOCAL_DB_FILE $UPSTREAM_DB_FILE %SCHEMA_DBS);
use fingerbank::Log;
use fingerbank::Schema::Local;
use fingerbank::Schema::Upstream;
use fingerbank::Util qw(is_success is_error is_disabled);
use fingerbank::DB_Factory;
use fingerbank::Status;

our @schemas = ($LOCAL_SCHEMA, $UPSTREAM_SCHEMA);

our %_HANDLES = ();


sub build_handle {
    my ( $self ) = @_;
    my $logger = fingerbank::Log::get_logger;

    my $schema = $self->schema;

    $logger->trace("Requesting schema '$schema' DB handle");

    # Check if the requested schema is a valid one
    my %schemas = map { $_ => 1 } @schemas;
    if ( !exists($schemas{$schema}) ) {
        $self->status_code($fingerbank::Status::INTERNAL_SERVER_ERROR);
        $self->status_msg("Requested schema '$schema' does not exists");
        $logger->warn($self->status_msg);
        return;
    }

    # Test requested schema DB file validity
    return if is_error($self->_test);

    my $file_path = $SCHEMA_DBS{$schema};

    my $file_timestamp = ( stat($file_path) )[9];

    if( $_HANDLES{$schema} && $file_timestamp <= $_HANDLES{$schema}->{timestamp} ){
        return $_HANDLES{$schema}->{handle};
    }

    $logger->info("Database $file_path was changed or handles weren't initialized. Creating handle.");

    # Returning the requested schema db handle
    my $handle = "fingerbank::Schema::$schema"->connect("dbi:SQLite:".$file_path);

    $handle->{AutoInactiveDestroy} = $TRUE;

    $_HANDLES{$schema} = { handle => $handle, timestamp => $file_timestamp };
    
    return $handle;
}

=head2 _test

Not meant to be used outside of this class

=cut

sub _test {
    my ( $self ) = @_;
    my $logger = fingerbank::Log::get_logger;

    my $schema = $self->schema;

    my $database_path = $INSTALL_PATH . "db/";
    my $database_file = fingerbank::Util::get_database_path($schema);

    $logger->trace("Testing '$schema' database");

    # Check if requested schema DB exists and is "valid"
    if ( (!-e $database_file) || (-z $database_file) ) {
        $self->status_code($fingerbank::Status::INTERNAL_SERVER_ERROR);
        $self->status_msg("Requested schema '$schema' DB file does not seems to be valid");
        $logger->error($self->status_msg);
        return $self->status_code;
    }

    # Check for read / write permissions with the effective uid/gid
    if ( (!-r $database_path) || (!-r $database_file) ) {
        $self->status_code($fingerbank::Status::INTERNAL_SERVER_ERROR);
        $self->status_msg("Requested schema '$schema' DB file does not seems to have the right permissions");
        $logger->error($self->status_msg);
        return $self->status_code;
    }

    $self->status_code($fingerbank::Status::OK);
    return $self->status_code;
}

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

__PACKAGE__->meta->make_immutable;

1;

