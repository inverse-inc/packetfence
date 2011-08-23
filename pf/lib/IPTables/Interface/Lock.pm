=head1 INTRODUCTION

 Wrapper interface to another locking scheme.  The issue/idea with
 this wrapper module, is that it is possible to change the underlying
 locking scheme/interface later on.

=head1 USAGE / DESIGN

 Ideas: ... want sub-locks based on that iptables chain we a messing with.

 ... want debugging info ... want to get informed if that locks
 actually gets used...

=head1 AUTHORS

  Jesper Dangaard Brouer (jdb@comx.dk) or (hawk@diku.dk).

=head1 SVN revision

 $Date: 2009-11-30 16:52:49 +0100 (Mon, 30 Nov 2009) $
 $LastChangedRevision: 1019 $
 $LastChangedBy: jdb $

=head1 TODO

 What underlying locking scheme/interface should be used???

 The use of an perl object seems overkill...

 Perhaps, remove the module and instead implement it directly in
 the module IPTables/Interface.pm which is the only real user.

=cut

package IPTables::Interface::Lock;

use strict;
use warnings;

# DCU logging system
#use DCU::logger;
use Log::Log4perl qw(get_logger :levels);
our $logger = get_logger(__PACKAGE__);
#$logger->level($DEBUG);

use IO::Handle;

# What locking module should we choose???
# ---------------------------------------
# Perl build-in "Fcntl" module
#use Fcntl qw(:DEFAULT :flock);
#
# CPAN module File::Flock
# http://search.cpan.org/~muir/File-Flock-104.111901/
# use File::Flock qw();
#
#
# Use Fcntl.pm which is part of perl-base
#
use POSIX qw(EAGAIN EACCES EWOULDBLOCK ENOENT EEXIST 
             O_EXCL O_CREAT O_RDWR O_TRUNC ); 
use Fcntl qw(LOCK_SH LOCK_EX LOCK_NB LOCK_UN :flock);

# S_IRWXU  00700 user (file owner) has read, write and execute permission
# S_IRUSR  00400 user has read permission
# S_IWUSR  00200 user has write permission
# S_IXUSR  00100 user has execute permission
#
# S_IRWXG  00070 group has read, write and execute permission
# S_IRGRP  00040 group has read permission
# S_IWGRP  00020 group has write permission
# S_IXGRP  00010 group has execute permission
#
# S_IRWXO  00007 others have read, write and execute permission
# S_IROTH  00004 others have read permission
# S_IWOTH  00002 others have write permission
# S_IXOTH  00001 others have execute permission

# Global variables
our $LOCK_DIR="/var/lock";


BEGIN {
  use Exporter ();
  our ($VERSION, @ISA, @EXPORT, @EXPORT_OK, %EXPORT_TAGS);

  # Package version
  $VERSION     = 0.2;
  @ISA         = qw(Exporter);
  @EXPORT      = qw();
}


# Create a new Lock Object.
sub new
{
    my $lock_name = shift;

    my $self = {};

    $self->{'lock_name'} = $lock_name;

    bless($self);
    return $self;
}

sub lock()
{
    my $self         = shift;
    my $lock_subname = shift;
    my $lock_file    = $self->get_lock_file($lock_subname);
    my $res;

    #my @callers = caller();
    #my ($package, $filename, $line) = caller();
    #print Dumper(@callers);

    $logger->debug("Locking Lock:[$lock_file]");

    my $fh;

    unless (sysopen($fh, $lock_file, O_CREAT|O_RDWR|O_TRUNC, 0644)) {
	$logger->logcroak("Cannot access lockfile:[$lock_file] $!");
    }

    # Save filehandle: Use for close when unlock or exit
    $self->{'lockHandles'}{"$lock_file"} = $fh;

    unless (flock($fh, LOCK_EX|LOCK_NB)) {
	$logger->warn("Blocking on Lock:[$lock_file]");
	unless(flock($fh, LOCK_EX)) {
	    $logger->logcroak("Cannot get Lock:[$lock_file]");
	}
	$logger->info("Continue after blocking on Lock:[$lock_file]");
    }

    # Put PID into file, is this a bad idea?
    #seek($fh, 0, 0);
    #truncate($fh, 0);
    print $fh $$ . "\n";
    flush $fh;

#    if(!($res = File::Flock::lock($lock_file, undef, 'nonblocking'))) {
#	$logger->warn("Blocking on Lock:[$lock_file]");
#	$res = File::Flock::lock($lock_file);
#	$logger->info("Continue after blocking on Lock:[$lock_file]");
#    }

    return $res;
}

sub trylock()
{
    my $self         = shift;
    my $lock_subname = shift;
    my $lock_file    = $self->get_lock_file($lock_subname);

    $logger->debug("Locking Lock:[$lock_file] (nonblocking)");

    my $fh;
    # unless (sysopen($fh, $lock_file, O_CREAT|O_RDWR)) {
    unless (sysopen($fh, $lock_file, O_CREAT|O_RDWR|O_TRUNC, 0644)) {
	$logger->logcroak("Cannot access lockfile:[$lock_file]");
    }
    my $res = flock($fh, LOCK_EX|LOCK_NB);

    # Extra things its possible the check for:
    #if (($! == EAGAIN) or
    #    ($! == EACCES) or
    #    ($! == EWOULDBLOCK)))

    # my $res = File::Flock::lock($lock_file, undef, 'nonblocking');
    return $res;
}

sub unlock()
{
    my $self         = shift;
    my $lock_subname = shift;
    my $lock_file    = $self->get_lock_file($lock_subname);

    $logger->debug("Unlocking Lock:[$lock_file]");

    # Get filehandle
    my $fh = $self->{'lockHandles'}{"$lock_file"};

    # Unlock using flock
    my $res = flock($fh, LOCK_UN);

    # Closing the filehandle also unlocks
    $res = close($fh);

    # Delete the hash
    delete $self->{'lockHandles'}{"$lock_file"};

    # my $res = File::Flock::unlock($lock_file);
    return $res;
}

sub get_lock_file()
{
    my $self         = shift;
    my $lock_subname = shift;

    my $lock_name = $self->{'lock_name'};
    my $lock_file;

    $lock_file = "$LOCK_DIR/$lock_name";

    if (defined $lock_subname) {
	$lock_file .= ".$lock_subname";
    }
    return $lock_file;
}

#END {
#    my $lock_file    = $self->get_lock_file();
#    if (exists $self->{'lockHandles'}{"$lock_file"}) {
#	$self->unlock();
#    }
#}

#END {
#    foreach my $lock_file (keys %$self->{'lockHandles'}) {
#	my $fh = $self->{'lockHandles'}{"$lock_file"};
#	flock($fh, LOCK_UN);
#	close($fh);
#    }
#}
