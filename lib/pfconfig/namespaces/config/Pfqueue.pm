package pfconfig::namespaces::config::Pfqueue;

=head1 NAME

pfconfig::namespaces::config::Pfqueue

=cut

=head1 DESCRIPTION

pfconfig::namespaces::config::Pfqueue

This module creates the configuration hash associated to pfqueue.conf

=cut

use strict;
use warnings;

use pfconfig::namespaces::config;
use pf::file_paths qw(
    $pfqueue_config_file
    $pfqueue_default_config_file
);
use pf::util;
use pf::constants::pfqueue qw(
    $PFQUEUE_WORKERS_DEFAULT
    $PFQUEUE_WEIGHT_DEFAULT
    $PFQUEUE_MAX_TASKS_DEFAULT
    $PFQUEUE_TASK_JITTER_DEFAULT
    $PFQUEUE_DELAYED_QUEUE_BATCH_DEFAULT
    $PFQUEUE_DELAYED_QUEUE_WORKERS_DEFAULT
    $PFQUEUE_DELAYED_QUEUE_SLEEP_DEFAULT
);

use base 'pfconfig::namespaces::config';

sub init {
    my ($self) = @_;
    $self->{file} = $pfqueue_config_file;
    my $defaults = pf::IniFiles->new(-file => $pfqueue_default_config_file);
    $self->{added_params}{'-import'} = $defaults;
}

sub build_child {
    my ($self) = @_;
    my %tmp_cfg = %{ $self->{cfg} };
    my $max_tasks = $tmp_cfg{pfqueue}{max_tasks};
    if (!defined($max_tasks) || $max_tasks <= 0) {
        $tmp_cfg{pfqueue}{max_tasks} = $PFQUEUE_MAX_TASKS_DEFAULT;
    }
    $tmp_cfg{pfqueue}{task_jitter} //= $PFQUEUE_TASK_JITTER_DEFAULT;
    foreach my $queue_section ( $self->GroupMembers('queue') ) {
        my $queue = $queue_section;
        $queue =~ s/^queue //;
        my $data = delete $tmp_cfg{$queue_section};
        # Set defaults
        $data->{workers} //= $PFQUEUE_WORKERS_DEFAULT;
        $data->{weight} //= $PFQUEUE_WEIGHT_DEFAULT;
        push @{$tmp_cfg{queues}},{ %$data, name => $queue };
    }
    my %redis_args;
    my $consumer = $tmp_cfg{consumer};
    foreach my $redis_key ( grep { /^redis_/ } keys %$consumer ) {
        my $option_key = $redis_key;
        $option_key =~ s/^redis_//;
        $redis_args{$option_key} = delete $consumer->{$redis_key};
    }
    $consumer->{redis_args} = \%redis_args;

    return \%tmp_cfg;
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

# vim: set shiftwidth=4:
# vim: set expandtab:
# vim: set backspace=indent,eol,start:
