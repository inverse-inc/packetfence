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

BEGIN {
    use Exporter ();
    our ( @ISA, @EXPORT_OK );
    @ISA = qw(Exporter);
    @EXPORT_OK = qw(task_counter_id consumer_redis_client);
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

sub consumer_redis_client {
    my ($self) = @_;
    return pf::Redis->new( %{$ConfigPfqueue{consumer}{redis_args}});
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
