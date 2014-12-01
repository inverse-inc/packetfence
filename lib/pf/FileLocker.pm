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

TODO: documention

=cut

sub DESTROY {
    my ($self) = @_;
    $self->unlock if $self->unlockOnDestroy && $self->lockAcquired;
}

=head2 unlock

TODO: documention

=cut

sub unlock {
    return $_[0]->_doRealLock( F_UNLCK );
}

=head2 _doLock

TODO: documention

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


=cut

sub _doRealLock {
    my ($self,$type) = @_;
    my $fs = $self->fcntlLock;
    $fs->l_type($type);
    my $result = $fs->lock($self->fh, $self->blocking ? F_SETLKW : F_SETLK);
    $self->lockAcquired($result);
    return $result;
}

=head2 writeLock

writeLock 

=cut

sub writeLock {
    return $_[0]->_doLock(F_WRLCK);
}

=head2 _doLock

TODO: documention

=cut

sub readLock {
    return $_[0]->_doLock(F_RDLCK);
}

=head2 isWriteLockedByAnother

See if there is a write lock on the file by another process

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

Copyright (C) 2005-2014 Inverse inc.

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

