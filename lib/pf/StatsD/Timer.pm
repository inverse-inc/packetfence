package pf::StatsD::Timer;

=head1 NAME

pf::StatsD::Timer -

=cut

=head1 DESCRIPTION

pf::StatsD::Timer

=cut

use strict;
use warnings;
use pf::StatsD;
use Time::HiRes;

=head2 $timer = $self->new({ 'stat' => "stat", sample_rate => $sample_rate });

=cut

sub new {
    my ($proto, $args) = @_;
    my $class = ref($proto) || $proto;
    $args //= {};
    $args->{start_time} //= Time::HiRes::gettimeofday;
    $args->{sample_rate} //= 0.25;
    #Get the name of the function enclosing this call
    $args->{'stat'} //= (caller(1))[3] . ".timing";
    my $start = Time::HiRes::gettimeofday();
    my $self  = {start_time => $start, sample_rate => 1.0, %$args};
    return bless $self, $class;
}

sub send_timing {
    my ($self, $sub_stat) = @_;
    $pf::StatsD::statsd->end($self->{'stat'} . ".$sub_stat", $self->{'start_time'}, $self->{'sample_rate'});
}

=head2 DESTROY

=cut

sub DESTROY {
    my ($self) = @_;
    $pf::StatsD::statsd->end($self->{'stat'}, $self->{'start_time'}, $self->{'sample_rate'});
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

