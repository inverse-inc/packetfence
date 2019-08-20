package CHI::Driver::DBI;

use strict;
use warnings;

use DBI::Const::GetInfoType;
use Moo;
use Carp qw(croak);
use Time::HiRes qw(time);

our $VERSION = '1.24';

extends 'CHI::Driver';

my $type = "CHI::Driver::DBI";

has 'db_name'      => ( is => 'rw', );
has 'dbh'          => ( is => 'ro');
has 'sql_strings'  => ( is => 'rw', builder => 1, lazy => 1 );
has 'table' => ( is => 'rw', default => 'chi_cache' );
has 'key_prefix' => ( is => 'rw', builder => 1, lazy => 1);

__PACKAGE__->meta->make_immutable unless $ENV{"PF_SKIP_MAKE_IMMUTABLE"};

sub BUILD {
    my ( $self, $args ) = @_;

    my $dbh = $self->dbh->();

    $self->db_name( $dbh->get_info( $GetInfoType{SQL_DBMS_NAME} ) );
    $self->sql_strings;

    if ( $args->{create_table} ) {
        $dbh->do( $self->sql_strings->{create} )
          or croak $dbh->errstr;
    }

    return;
}

sub _table {
    my ( $self, ) = @_;

    return $self->table();
}

sub _build_key_prefix {
    my ( $self ) = @_;
    return $self->namespace . "::";
}

sub namespaced_key {
    my ($self, $key) = @_;
    return $self->key_prefix . $key;
}

sub _build_sql_strings {
    my ( $self, ) = @_;

    my $dbh   = $self->dbh->();
    my $table = $dbh->quote_identifier( $self->_table );
    my $value = $dbh->quote_identifier('value');
    my $expires_at = $dbh->quote_identifier('expires_at');
    my $key_prefix_match = $dbh->quote( $self->key_prefix . "%" );
    my $key   =  $dbh->quote_identifier('key');

    my $strings = {
        fetch    => "SELECT $value FROM $table WHERE $key = ? and ? < $expires_at",
        store    => "INSERT INTO $table ( $key, $value, $expires_at ) VALUES ( ?, ?, ? )",
        store2   => "UPDATE $table SET $value = ?, $expires_at = ? WHERE $key = ?",
        remove   => "DELETE FROM $table WHERE $key = ?",
        clear    => "DELETE FROM $table where $key like $key_prefix_match",
        get_keys => "SELECT DISTINCT $key FROM $table where $key like $key_prefix_match and ? < $expires_at",
        create   => <<EOF
CREATE TABLE IF NOT EXISTS $table (
  $key VARCHAR(767),
  $value LONGBLOB,
  $expires_at REAL,
  PRIMARY KEY ($key)
)
EOF
    };

    if ( $self->db_name eq 'MySQL' ) {
        $strings->{store} =
            "INSERT INTO $table"
          . " ( $key, $value, $expires_at )"
          . " VALUES ( ?, ?, ? )"
          . " ON DUPLICATE KEY UPDATE $value=VALUES($value), $expires_at=VALUES($expires_at)";
        delete $strings->{store2};
    }
    elsif ( $self->db_name eq 'SQLite' ) {
        $strings->{store} =
            "INSERT OR REPLACE INTO $table"
          . " ( $key, $value, $expires_at )"
          . " values ( ?, ?, ? )";
        delete $strings->{store2};
    }
    return $strings;
}

sub fetch {
    my ( $self, $key, ) = @_;

    my $dbh = $self->dbh->();
    my $sth = $dbh->prepare_cached( $self->sql_strings->{fetch} )
      or croak $dbh->errstr;
    $sth->execute($self->namespaced_key($key), time) or croak $sth->errstr;
    my $results = $sth->fetchall_arrayref;

    return $results->[0]->[0];
}

sub store {
    my ( $self, $key, $data, $expires_in) = @_;

    # Setting the max to the max unix timestamp
    my $expires_at = defined($expires_in) ? time + $expires_in : 2147483641;

    my $dbh = $self->dbh->();
    my $sql_strings = $self->sql_strings;
    my $sth = $dbh->prepare_cached( $sql_strings->{store} );
    if ( not $sth->execute( $self->namespaced_key($key), $data, $expires_at ) ) {
        my $store2 = $sql_strings->{store2};
        if ($store2) {
            my $sth = $dbh->prepare_cached($store2)
              or croak $dbh->errstr;
            $sth->execute( $data, $expires_at, $self->namespaced_key($key) )
              or croak $sth->errstr;
        }
        else {
            croak $sth->errstr;
        }
    }
    $sth->finish;

    return;
}

sub remove {
    my ( $self, $key, ) = @_;

    my $dbh = $self->dbh->();
    my $sth = $dbh->prepare_cached( $self->sql_strings->{remove} )
      or croak $dbh->errstr;
    $sth->execute($self->namespaced_key($key)) or croak $sth->errstr;
    $sth->finish;

    return;
}

sub clear {
    my ( $self, $key, ) = @_;

    my $dbh = $self->dbh->();
    my $sth = $dbh->prepare_cached( $self->sql_strings->{clear} )
      or croak $dbh->errstr;
    $sth->execute() or croak $sth->errstr;
    $sth->finish();

    return;
}

sub get_keys {
    my ( $self, ) = @_;

    my $dbh = $self->dbh->();
    my $sth = $dbh->prepare_cached( $self->sql_strings->{get_keys} )
      or croak $dbh->errstr;
    $sth->execute(time) or croak $sth->errstr;
    my $results = $sth->fetchall_arrayref( [0] );

    my $key_prefix = $self->key_prefix;
    my @stripped_results;
    foreach my $result (@{$results}) {
        my $stripped = $result->[0];
        $stripped =~ s/^$key_prefix//g;
        push @stripped_results, $stripped;
    }
    return @stripped_results;
}

sub get_namespaces { croak 'not supported' }

# TODO:  For pg see "upsert" - http://www.postgresql.org/docs/current/static/plpgsql-control-structures.html#PLPGSQL-UPSERT-EXAMPLE

1;

__END__

=head1 NAME

CHI::Driver::DBI - Use DBI for cache storage

=head1 SYNOPSIS

    use CHI;
    
    # Supply a DBI handle
    #
    my $cache = CHI->new( driver => 'DBI', dbh => DBI->connect(...) );
    
    # or a DBIx::Connector
    #
    my $cache = CHI->new( driver => 'DBI', dbh => DBIx::Connector->new(...) );
    
    # or code that generates a DBI handle
    #
    my $cache = CHI->new( driver => 'DBI', dbh => sub { ...; return $dbh } );

=head1 DESCRIPTION

This driver uses a database table to store the cache.  The newest versions of
MySQL and SQLite work are known to work.  Other RDBMSes should work.

Why cache things in a database?  Isn't the database what people are trying to
avoid with caches?  This is often true, but a simple primary key lookup is
extremely fast in many databases and this provides a shared cache that can be
used when less reliable storage like memcached is not appropriate.  Also, the
speed of simple lookups on MySQL when accessed over a local socket is very hard
to beat.  DBI is fast.

=for readme stop

=head1 SCHEMA

Each namespace requires a table like this:

    CREATE TABLE chi_<namespace> (
       `key` VARCHAR(...),
       `value` TEXT,
       PRIMARY KEY (`key`)
    )

The size of the key column depends on how large you want keys to be and may be
limited by the maximum size of an indexed column in your database.

The driver will try to create an appropriate table for you if you pass
C<create_table> to the constructor.

=head1 CONSTRUCTOR PARAMETERS

=over

=item create_table

Boolean. If true, attempt to create the database table if it does not already
exist. Defaults to false.

=item namespace

The namespace you pass in will be appended to the C<table_prefix> to form the
table name.  That means that if you don't specify a namespace or table_prefix
the cache will be stored in a table called C<chi_Default>.

=item table_prefix

This is the prefix that is used when building a table name.  If you want to
just use the namespace as a literal table name, set this to the empty string. 
Defaults to C<chi_>.

=item dbh

A code ref to get the DBI handle used to communicate with the db.

=back

=for readme continue

=head1 AUTHORS

Original version by Justin DeVuyst and Perrin Harkins. Currently maintained by
Jonathan Swartz.

=cut
