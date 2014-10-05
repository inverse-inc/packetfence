package pf::api::inline;
=head1 NAME

pf::api::inline add documentation

=cut

=head1 DESCRIPTION

pf::api::inline

=cut

use strict;
use warnings;
use pf::api;
use pf::db;
use POSIX qw(:sys_wait_h);
use Moo;

sub call {
    my ($self,$method,@args) = @_;
    return pf::api->$method(@args);
}

sub notify {
    my ($self,$method,@args) = @_;
    my $pid = fork();
    if ($pid) {
        #cleanup child
        waitpid($pid,0);
        return;
    }
    if( defined $pid && $pid == 0 ) {
        if($pf::db::DBH) {
            $pf::db::DBH->{InactiveDestroy} = 1;
            $pf::db::DBH = undef;
        }
        my $pid2 = fork();
        POSIX::_exit(0) unless defined $pid2 && $pid2 == 0;
        $self->call($method,@args);
        exit 0;
    }
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

