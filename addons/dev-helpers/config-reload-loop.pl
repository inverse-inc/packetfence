#!/usr/bin/perl

=head1 NAME

loop add documentation

=cut

=head1 DESCRIPTION

loop

=cut

use strict;
use warnings;
use lib qw(/usr/local/pf/lib);
use pf::config::cached;
use pf::ConfigStore::Switch;
use Cache::Memcached;
use pf::db;

use POSIX qw(:sys_wait_h pause);
our %KIDS;
$SIG{CHLD} = sub { };
$SIG{INT} = $SIG{TERM} = sub {kill INT => keys %KIDS};
our $RUNNING = 1;
our $reloaded = 0;
$pf::ConfigStore::Switch::switches_cached_config->addFileReloadCallbacks(
    onfilereload => sub {print STDERR "$$ onfilereload " . time . "\n"});
$pf::ConfigStore::Switch::switches_cached_config->addCacheReloadCallbacks(
    oncachereload => sub {print STDERR "$$ oncachereload " . time . "\n"});

{
    Cache::Memcached->disconnect_all;
    pf::CHI->clear_memoized_cache_objects;
    db_disconnect();
}
#    local $pf::config::cached::NO_DESTROY = 1;

for (1 .. 30) {
    my $pid = fork;
    last unless defined $pid;
    if ($pid) {
        $KIDS{$pid} = undef;
    }
    else {
        $SIG{CHLD} = 'DEFAULT';
        $SIG{INT} = $SIG{TERM} = sub { $RUNNING = 0; };
        use pf::log reinit => 1;
        Log::Log4perl::MDC->put( 'tid', $$ );
        doReload();   
        exit;
    }
}

sub doReload {
    while ($RUNNING) {
#        print "$$ ",time,"\n";
        pf::config::cached::RefreshConfigs();
        sleep 2;
    }

}

print STDERR "Starting waiting\n";

while (1) {
    pause;
    while (1) {
        my $pid = waitpid(-1, WNOHANG);
        last unless $pid > 0;
        delete $KIDS{$pid};
    }
    last unless keys %KIDS;
}

=head1 AUTHOR

Inverse inc. <info@inverse.ca>

=head1 COPYRIGHT

Copyright (C) 2005-2014 Inverse inc.

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

