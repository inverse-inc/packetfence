#!/usr/bin/perl

package pf::addons::cleaner;

=head1 NAME

pf::addons::cleaner

=head1 SYNOPSIS

 database-cleaner --table=<table> --date-field=<date-field> <other options>

Options:

  table                 | Name of the table to clean
  date-field            | The date field to compare against for the expiration
  older-than            | Delay of expiration of the entries in SQL syntax. Defaults to "1 MONTH".
  run-limit             | Amount of rows to delete per run
  wait-between          | Time to wait between runs
  additionnal-condition | Additionnal SQL condition to add to the cleanup queries
  seed                  | Add dummy data in radacct to test the script

=head1 DESCRIPTION

This module allows to perform a database cleanup that aims to not lock the tables for too much time.

=cut



use strict;
use warnings;

use lib '/usr/local/pf/lib';
BEGIN {
  use Log::Log4perl qw(get_logger);
  my $log_conf = q(
  log4perl.rootLogger              = INFO, SCREEN
  log4perl.appender.SCREEN         = Log::Log4perl::Appender::Screen
  log4perl.appender.SCREEN.stderr  = 0
  log4perl.appender.SCREEN.layout  = Log::Log4perl::Layout::PatternLayout
  log4perl.appender.SCREEN.layout.ConversionPattern = %d{MMM dd HH:mm:ss} : %m %n
  );
  Log::Log4perl::init(\$log_conf);
}

use pf::db;
use DBI;
use Data::Dumper;
use Getopt::Long;
use Pod::Usage;


=head2 new

Create a new cleaner object

=cut

sub new {
    my ($class, %options) = @_;
    my $self = bless {}, $class;

    my $host = $pf::db::DB_Config->{'host'};
    my $port = $pf::db::DB_Config->{'port'};
    my $user = $pf::db::DB_Config->{'user'};
    my $pass = $pf::db::DB_Config->{'pass'};
    my $db   = $pf::db::DB_Config->{'db'};

    $self->{dbh} = DBI->connect( "dbi:mysql:dbname=$db;host=$host;port=$port",
        $user, $pass, { RaiseError => 1, PrintError => 0, mysql_auto_reconnect => 1 } );

    while (my ($key, $value) = each %options) {
        $self->{$key} = $value;
    }

    return $self;
}

=head2 seed_data

Seed fake data in the radacct table to test this script

=cut

sub seed_data {
    my ($self) = @_;

    my $sth = $self->{dbh}->prepare("INSERT INTO `radacct` (`acctsessionid`, `acctuniqueid`, `acctstarttime`) VALUES (?,?,?)");

    foreach my $i (1..10000) {
        $sth->bind_param(1, int(rand(10000)));
        $sth->bind_param(2, "dinde");
        $sth->bind_param(3, "2014-01-01");
        $sth->execute();
    }
}

=head2 clean

Do the cleanup of the table based on the objects options

=cut

sub clean {
    my ($self) = @_;
    my $TABLE = $self->{'table'} || die_with_help("Missing table argument");
    my $DATE_FIELD = $self->{'date-field'} || die_with_help("Missing date-field argument");
    my $OLDER_THAN = $self->{'older-than'} || "1 MONTH";
    my $RUN_LIMIT = $self->{'run-limit'} || 500;
    my $WAIT_BETWEEN = $self->{'wait-between'} || 0.5;
    my $ADDITIONNAL_CONDITIONS = $self->{'additionnal-condition'} || "(1=1)";

    my $sth = $self->{dbh}->prepare("select count(*) from $TABLE where $DATE_FIELD <  ( NOW() - INTERVAL $OLDER_THAN ) AND $ADDITIONNAL_CONDITIONS");
    $sth->execute();
    my @result = $sth->fetchrow_array;

    my $amount_to_delete = $result[0];

    my $runs = int($amount_to_delete / $RUN_LIMIT)+1;

    get_logger->info("Deleting $amount_to_delete entries from $TABLE in $runs runs batching $RUN_LIMIT at the time waiting $WAIT_BETWEEN seconds between runs.");

    my $i=0;
    for(my $i=1; $i<=$runs; $i++){
        get_logger->debug("Executing run $i");
        for (my $try=1; $try<=10; $try++) {
            eval {
                $sth = $self->{dbh}->prepare("delete from $TABLE where $DATE_FIELD < ( NOW() - INTERVAL $OLDER_THAN ) AND $ADDITIONNAL_CONDITIONS limit $RUN_LIMIT");
                $sth->execute();
            };
            if($@) {
                get_logger->error("Failed to delete rows on iteration $i - try $try ($@). Retrying");
            }
            else {
                get_logger->debug("Deleted rows");
                last;
            }
        }
        select(undef,undef,undef,$WAIT_BETWEEN);
    }
}

=head2 die_with_help

Die with an error message and by showing the help

=cut

sub die_with_help {
    my ($message) = @_;
    print STDERR "$message\n";
    pod2usage( -verbose => 1 );
}

=head2 execute

Main method/entry point of the script.

=cut

sub execute {
    my %options = ();
    GetOptions (
      \%options,
      "h!",
      "table=s",
      "date-field=s",
      "older-than=s",
      "run-limit=i",
      "wait-between=f",
      "additionnal-condition=s",
      "seed!",
    ) || die_with_help("Invalid options");

    die_with_help("Help : ") if($options{h});

    my $cleaner = pf::addons::cleaner->new(%options);
    if($cleaner->{seed}){
        $cleaner->seed_data();
    }
    $cleaner->clean();
}

execute();

