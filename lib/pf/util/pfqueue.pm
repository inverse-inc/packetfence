package pf::util::pfqueue;

=head1 NAME

pf::util::pfqueue - pfqueue

=cut

=head1 DESCRIPTION

=head1 WARNING

=cut

use strict;
use warnings;
use pf::log;
use pf::config::pfqueue;
use pf::Redis;
use pf::Sereal qw(sereal_decode_safe);
use Module::Pluggable
  search_path => 'pf::task',
  sub_name    => '_task_modules',
  inner       => 0,
  require     => 0;

BEGIN {
    use Exporter ();
    our ( @ISA, @EXPORT_OK );
    @ISA = qw(Exporter);
    @EXPORT_OK = qw(task_counter_id consumer_redis_client decode_task is_valid_task_type);
}

=head1 SUBROUTINES

=head2 $id = task_counter_id($queue, $type, $args)

Create the counter id for a queue task

=cut

sub task_counter_id {
    my ($queue, $type, $args) = @_;
    my $counter_id = "${queue}:${type}";
    my $args_ref = ref ($args);
    if ($type eq 'api' && $args_ref eq 'ARRAY') {
        $counter_id .= ":" . $args->[0];
    }
    elsif ($type eq 'pfsnmp_parsing' && $args_ref eq 'ARRAY') {
        $counter_id .= ":" . $args->[0]->{switchIp};
    }
    elsif ($type eq 'pfsnmp' && $args_ref eq 'HASH') {
        $counter_id .= join(":","", $args->{switchId}, $args->{trapIfIndex}, $args->{'trapType'});
    }

    return $counter_id;
}

=head2 consumer_redis_client

=cut

=head2 is_valid_task_type

Check if the type is the name of a pf::task module.
The names are read from the file system the first time, the modules are not loaded.

=cut

our %TASK_TYPES;

sub is_valid_task_type {
    my ($type) = @_;
    return 0 if !defined($type) || ref($type);
    %TASK_TYPES = map { /^pf::task::(\w+)$/ ? ($1 => 1) : () } __PACKAGE__->_task_modules unless %TASK_TYPES;
    return exists $TASK_TYPES{$type} ? 1 : 0;
}

=head2 decode_task

Decode a task stored in the queue.
Returns the task ([$type, $args]), or undef and an error message when the data can't be
decoded or the task type isn't one of the pf::task modules.

=cut

sub decode_task {
    my ($data) = @_;
    my $item = eval { sereal_decode_safe($data) };
    my $decode_error = $@;
    if (ref($item) eq 'ARRAY' && is_valid_task_type($item->[0])) {
        return ($item, undef);
    }

    return (undef, "Invalid task stored in queue" . ($decode_error ? ": $decode_error" : ""));
}

sub consumer_redis_client {
    my ($self) = @_;
    return pf::Redis->new( %{$ConfigPfqueue{consumer}{redis_args}});
}

=head1 AUTHOR

Inverse inc. <info@inverse.ca>

=head1 COPYRIGHT

Copyright (C) 2005-2026 Inverse inc.

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
