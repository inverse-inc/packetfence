package pf::CHI::db;

=head1 NAME

pf::CHI::db -

=head1 DESCRIPTION

pf::CHI::db

=cut

use strict;
use warnings;
use POSIX::AtFork;
use DBI;
use pf::log;
use pf::IniFiles;
use List::MoreUtils qw(uniq);
use pf::file_paths qw(
    $pf_default_file
    $pf_config_file
);

our ($DBH, $LAST_CONNECT, $CONFIG);
our $logger = get_logger();

our $pf_default_config = pf::IniFiles->new(-file => $pf_default_file) or die "Cannot open $pf_default_file";
our $pf_config = pf::IniFiles->new( -file => $pf_config_file, -allowempty => 1, -import => $pf_default_config) or die "Cannot open $pf_config_file";
($CONFIG->{db},$CONFIG->{host},$CONFIG->{port},$CONFIG->{user},$CONFIG->{pass}) = @{sectionData($pf_config, "database")}{qw(db host port user pass)};

sub CLONE {
    if ($DBH) {
        my $clone = $DBH->clone();
        $DBH->{InactiveDestroy} = 1;
        undef $DBH;
        $DBH = $clone;
        $LAST_CONNECT = time();
    }
}

sub db_connect {
    if (is_old_connection_good($DBH)) {
        return $DBH;
    }

    $logger->debug("(Re)Connecting to MySQL (pid: $$)");
    my ($dsn, $user, $pass) = db_data_source_info();
    # make sure we have a database handle
    if ($DBH = DBI->connect($dsn, $user, $pass, { RaiseError => 0, PrintError => 0, mysql_auto_reconnect => 1 })) {
        $logger->debug("connected");
        return $DBH;
    }

    $logger->logcroak("unable to connect to database: " . $DBI::errstr);
    return undef;
}

=head2 db_data_source_info

db_data_source_info

=cut

sub db_data_source_info {
    return (
        "dbi:mysql:dbname=$CONFIG->{db};host=$CONFIG->{host};port=$CONFIG->{port}",
        $CONFIG->{user}, $CONFIG->{pass}
    );
}

=head2 is_old_connection_good

is_old_connection_good

=cut

sub is_old_connection_good {
    my ($dbh) = @_;
    if (!defined $dbh) {
        return 0;
    }

    if (was_recently_connected()) {
        $logger->debug("not checking db handle, it has been less than 30 sec from last connection");
        return 1;
    }

    $logger->debug("checking handle");
    if ( $dbh->ping() ) {
        $LAST_CONNECT = time();
        $logger->debug("we are currently connected");
        return 1;
    }

    return 0;
}

sub was_recently_connected {
    return defined($LAST_CONNECT) && $LAST_CONNECT && (time()-$LAST_CONNECT < 30);
}

sub sectionData {
    my ($ci, $sect) = @_;
    my %args;
    foreach my $p ( $ci->Parameters($sect) ) {
        my $val = $ci->val( $sect, $p );
        $args{$p} = $1 if $val =~ /^(.*)$/;
    }

    my @sects = uniq map { s/^$sect ([^ ]+).*$//; $1 } grep { /^$sect / } $ci->Sections;
    foreach my $name (@sects) {
        $args{$name} = sectData( $ci, "$sect $name" );
    }

    return \%args;
}

POSIX::AtFork->add_to_child(\&CLONE);

END {
    $DBH->disconnect if $DBH;
    $DBH = undef;
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
