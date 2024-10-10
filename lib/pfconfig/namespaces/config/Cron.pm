package pfconfig::namespaces::config::Cron;

=head1 NAME

pfconfig::namespaces::config::Cron

=cut

=head1 DESCRIPTION

pfconfig::namespaces::config::Cron

This module creates the configuration hash associated to maintenance.conf

=cut

use strict;
use warnings;

use pfconfig::namespaces::config;
use pf::file_paths qw($cron_config_file $cron_default_config_file);
use pf::util qw(normalize_time);
use pf::IniFiles;
use Clone qw(clone);

use base 'pfconfig::namespaces::config';

sub init {
    my ($self) = @_;
    $self->{file} = $cron_config_file;
    my $defaults = pf::IniFiles->new(-file => $cron_default_config_file, -envsubst => 1);
    $self->{added_params}{'-import'} = $defaults;
}

my %golangUnits = (
    "s" => 1,
    "m" => 60,
    "h" => 3600,
);

sub golangDurationToSeconds {
    my ($d) = @_;
    my $i;
    while ($d =~ /([0-9\.-]+)([a-zA-Z])/g) {
        next if !exists $golangUnits{$2};
        $i += $1 * $golangUnits{$2};
    }

    return $i;
}

sub build_child {
    my ($self) = @_;
    my $tmp_cfg = clone($self->{cfg});
    foreach my $task_data (values %$tmp_cfg) {
        foreach my $key (keys %$task_data) {
            if ($key =~ /(window|timeout)$/ ) {
                $task_data->{$key} = normalize_time($task_data->{$key});
                next;
            }

            if ($key eq 'filter_events' || $key eq 'heuristics') {
                $task_data->{$key} += 0;
                next;
            }

            if ($key =~ /batch$/) {
                $task_data->{$key} += 0;
            }
        }

        my $schedule = $task_data->{schedule};
        my $interval = 60;
        if ($schedule =~ /^\@every (.*)$/) {
            $interval = golangDurationToSeconds($1);
        }

        $task_data->{interval} = $interval;
        if (exists $task_data->{kafka_brokers}) {
            $task_data->{kafka_brokers} = [split(/\s*,\s*/, $task_data->{kafka_brokers})];
        }
    }

    return $tmp_cfg;
}


=head1 AUTHOR

Inverse inc. <info@inverse.ca>

=head1 COPYRIGHT

Copyright (C) 2005-2024 Inverse inc.

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

