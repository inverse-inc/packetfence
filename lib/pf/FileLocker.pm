package pf::FileLocker;
=head1 NAME

pf::FileLocker add documentation

=cut

=head1 DESCRIPTION

pf::FileLocker

=cut

use strict;
use warnings;
use File::FcntlLock;
use pf::log;
use Moo;
use POSIX qw(SIGALRM);

has fcntlLock => (
    is      => 'ro',
    default => sub {
        return File::FcntlLock->new(
            l_type   => F_WRLCK,
            l_whence => SEEK_SET,
            l_start  => 0,
            l_len    => 0
        );
    }
);
has fh => ( is => 'rw', required => 1 );
has blocking => ( is => 'rw', default => sub { 0 } );
has unlockOnDestroy => ( is => 'rw', default => sub { 0 } );
has timeout => ( is => 'rw', default => sub { 0 } );
has lockAcquired => ( is => 'rw', default => sub { 0 } );

=head2 DESTROY

Unlocks the file on destroy of the object

=head3 Usage

    DESTROY()

=head3 Return

    Nothing

=cut

sub DESTROY {
    my ($self) = @_;
    $self->unlock if $self->unlockOnDestroy && $self->lockAcquired;
}

=head2 unlock

Unlocks the file handle

=head3 Usage

    $obj->unlock()

=head3 Return

    1 on success
    0 on failure

=cut

sub unlock {
    return $_[0]->_doRealLock( F_UNLCK );
}

=head2 _doLock

Wraps the (un)locking of the file handle to deal with timeouts

=head3 Usage

    $obj->_doLock()

=head3 Return

    1 on success
    0 on failure


=cut

sub _doLock {
    my ($self, $type) = @_;
    my $timeout = $self->timeout;
    my $blocking = $self->blocking;
    if ($timeout && $blocking) {
        my $mask      = POSIX::SigSet->new(SIGALRM);
        my $action    = POSIX::SigAction->new(sub { die "alarm" }, $mask);
        my $oldaction = POSIX::SigAction->new();
        my $result;
        POSIX::sigaction(SIGALRM, $action, $oldaction);
        eval {
            alarm $timeout;
            eval {
                $result = $self->_doRealLock($type);
            };
            alarm 0;
            POSIX::sigaction(SIGALRM, $oldaction);    # restore original
        };
        alarm 0;
        return $result;
    }
    return $self->_doRealLock($type);
}

=head2 _doRealLock

Wraps the (un)locking of the file handle to deal with blocking locks

=head3 Usage

    $obj->_doRealLock()

=head3 Return

    1 on success
    0 on failure


=cut

sub _doRealLock {
    my ($self,$type) = @_;
    my $fs = $self->fcntlLock;
    $fs->l_type($type);
    my $result = $fs->lock($self->fh, $self->blocking ? F_SETLKW : F_SETLK) ? 1 : 0;
    $self->lockAcquired($result);
    return $result;
}

=head2 writeLock

Get the write lock on the file handle

=head3 Usage

    $obj->writeLock()

=head3 Return

    1 on success
    0 on failure

=cut

sub writeLock {
    return $_[0]->_doLock(F_WRLCK);
}

=head2 readLock

Get the read lock on the file handle

=head3 Usage

    $obj->readLock()

=head3 Return

    1 on success
    0 on failure

=cut

sub readLock {
    return $_[0]->_doLock(F_RDLCK);
}

=head2 isWriteLockedByAnother

Check if a write lock is own by another process for the file handle

=head3 Usage

    $obj->isWriteLockedByAnother()

=head3 Return

    1 on success
    0 on failure

=cut

sub isWriteLockedByAnother {
    my ($self) = @_;
    my $fs = $self->fcntlLock;
    $fs->lock($self->fh, F_GETLK);
    return F_WRLCK == $fs->l_type && $fs->l_pid != $$;
}

=head1 AUTHOR

Inverse inc. <info@inverse.ca>

=head1 COPYRIGHT

Copyright (C) 2005-2015 Inverse inc.

=head1 LICENSE

This program is free software; you can redistribute it and::or
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

