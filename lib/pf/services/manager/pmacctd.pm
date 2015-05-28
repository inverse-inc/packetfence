package pf::services::manager::pmacctd;
=head1 NAME

pf::services::manager::pmacctd add documentation

=cut

=head1 DESCRIPTION

pf::services::manager::pmacctd

=cut

use strict;
use warnings;
use Moo;
use pf::config;
use pf::util;
use List::MoreUtils qw(uniq);
use Linux::Inotify2;
use pf::log;

extends 'pf::services::manager::submanager';

has pmacctdManagers => (is => 'rw', builder => 1, lazy => 1);

has _pidFiles => (is => 'rw', default => sub { {} } );

has '+name' => (default => sub { 'pmacctd'} );

has '+optional' => ( default => sub {1} );

sub _build_pmacctdManagers {
    my ($self) = @_;
    my @managers = map {
        pf::services::manager->new ({
            executable => $self->executable,
            name => "pmacctd_".$_->tag("int"),
            launcher => "sudo %1\$s -D -P memory -i ".$_->tag("int")." -c src_host,dst_port -F $var_dir/run/pmacctd_".$_->tag("int").".pid -p $var_dir/pmacctd_".$_->tag("int").".pipe &",
            forceManaged => $self->isManaged,
        })
    } grep { is_type_inline($Config{"interface ".$_->tag("int").""}{'enforcement'}) } uniq @internal_nets;
    return \@managers;
}

=head2 _setupWatchForPidCreate

Setting up inotify to watch for the creation of pidFiles for each pmacctd instance

=cut

sub _setupWatchForPidCreate {
    my ($self) = @_;
    my $inotify = $self->inotify;
    my %pidFiles = map { $_->pidFile => undef } $self->managers;
    my $run_dir = "$var_dir/run";
    $inotify->watch ($run_dir, IN_CREATE, sub {
        my $e = shift;
        delete @pidFiles{ grep { -e $_ } keys %pidFiles };
        $e->w->cancel unless keys %pidFiles;
    });
}

sub postStartCleanup {
    my ($self,$quick) = @_;
    my $result = 0;
    my $inotify = $self->inotify;
    my @pidFiles = map { $_->pidFile } $self->managers;
    my $logger = get_logger;
    if ( @pidFiles && any { ! -e $_ } @pidFiles ) {
        my $timedout;
        eval {
            local $SIG{ALRM} = sub { die "alarm clock restart" };
            alarm 60;
            eval {
                 1 while $inotify->poll;
            };
            alarm 0;
            $timedout = 1 if $@ && $@ =~ /^alarm clock restart/;
        };
        alarm 0;
        $logger->warn($self->name . " timed out trying to start" ) if $timedout;
    }
    return all { -e $_ } @pidFiles;
}


sub managers {
    my ($self) = @_;
    return @{$self->pmacctdManagers};
}

sub isManaged {
    my ($self) = @_;
    return $TRUE if (grep { is_type_inline($Config{"interface ".$_->tag("int").""}{'enforcement'}) } uniq @internal_nets);
    return $FALSE;
}

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

