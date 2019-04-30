#!/usr/bin/perl

=head1 NAME

pfqueue -

=head1 DESCRIPTION

pfqueue

=cut

use strict;
use warnings;
use lib qw(/usr/local/pf/lib);
use pf::pfqueue::producer::redis;
use pf::pfqueue::consumer::redis;
use pf::config::pfqueue;
use Data::Dumper;

{
    package pf::task::test;
    use strict;
    use pf::error qw(is_error);
    use warnings;
    use base 'pf::task';

    sub doTask {
        my ($self, $args) = @_;
        unless (ref $args) {
            return undef, $args;
        }

        my $status = $args->{status};
        unless ($status) {
            return undef, $args;
        }

        if ($status eq 'die') {
            die 'die';
        }

        if (is_error($status)) {
            return $args, undef;
        }

        return undef, $args;
    }
}

my $client = pf::pfqueue::producer::redis->new();
$client->redis->flushall();
my @tasks;
push @tasks, $client->submit("test", "test" => {}, undef,  status_update => 1);
push @tasks, $client->submit("test", "test" => { status => "die"}, undef,  status_update => 1);
push @tasks, $client->submit("test", "test" => { status => 200, message => 'blah blah'}, undef,  status_update => 1);
push @tasks, $client->submit("test", "test" => { status => 422, message => 'bad bad'}, undef,  status_update => 1);
push @tasks, $client->submit("test", "test" => "test", undef,  status_update => 1);
my $consumer =  pf::pfqueue::consumer::redis->new({ %{$ConfigPfqueue{"consumer"}}, redis_name => "test $$" });

for (1..scalar @tasks) {
    $consumer->process_next_job(["Queue:test"]);
}

my $redis = $consumer->redis;
for my $task (@tasks) {
    my %r = $redis->hgetall("$task-Status");
    print STDERR Data::Dumper->Dump([\%r], [$task]);
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

