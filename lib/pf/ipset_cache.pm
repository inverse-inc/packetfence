package pf::ipset_cache;

=head1 NAME

pf::ipset_cache - Ipset Cache

=cut

=head1 DESCRIPTION

pf::ipset_cache

Maintain a CHI cache between a ipset hash:ip,port set

=cut

use strict;
use warnings;
use Moo;
use CHI;
use pf::log;
use pf::util qw(pf_run);

our $logger = get_logger();

has ipset_binary => (is => 'ro', default => sub { 'ipset' });

has cache => (is => 'ro', builder => 1, lazy => 1);

has setname => (is => 'ro', required => 1);

=head2 _build_cache

Build a memory CHI cache

=cut

sub _build_cache {
    my ($self) = @_;
    return CHI->new(driver => 'RawMemory', datastore => {}, namespace => $self->setname);
}

=head2 add_pairs

Add ip port pairs

=cut

sub add_pairs {
    my ($self, $ip_port_pairs) = @_;
    my @pairs = grep {!$self->is_in_cache($_) } @$ip_port_pairs;
    if (@pairs) {
        unless ($self->_add_pairs_to_ipset(\@pairs)) {
            return undef;
        }
        $self->_add_pairs_to_cache(\@pairs);
    }
    return scalar @pairs;
}

=head2 is_in_cache

Check to see if a ip port pair is in the cache

=cut

sub is_in_cache {
    my ($self, $pair) = @_;
    unless (ref ($pair) eq 'HASH' && exists $pair->{ip} && defined $pair->{ip} && exists $pair->{port} && defined $pair->{ip} ) {
        return undef;
    }
    return $self->cache->is_valid(_format_pair($pair));
}


=head2 _add_pairs_to_ipset

Add the ip port pairs to the ipset session

=cut

sub _add_pairs_to_ipset {
    my ($self, $pairs) = @_;
    my $setname = $self->setname;
    my $binary = $self->ipset_binary;
    my $data = join("\n", (map { "add $setname " . _format_pair($_) } @$pairs), "");
    my $pid = open(my $ipset, "| LANG=C sudo $binary -! restore 2>&1");
    unless (defined $pid) {
        $logger->error("Cannot start ipset ");
        return undef;
    }
    $logger->trace("ipset process pid : $pid");
    print $ipset $data;
    close($ipset);
    waitpid($pid, 0);
    return 1;
}

=head2 _add_pairs_to_cache

Add the ip port pairs to the cache

=cut

sub _add_pairs_to_cache {
    my ($self, $pairs) = @_;
    my %data = map { _format_pair($_) => 1 } @$pairs;
    $self->cache->set_multi(\%data);
}

=head2 _format_pair

Format pair to the ip,port

=cut

sub _format_pair {
    my ($pair) = @_;
    my $port = _format_port($pair->{port});
    return "$pair->{ip},$port";
}

=head2 _format_port

Format port

=cut

sub _format_port {
    my ($port) = @_;
    if ($port =~ /^\d+$/) {
        $port = "tcp:$port";
    }
    return $port;
}

=head2 populate_cache

Populate cache from the ipset setname

=cut

sub populate_cache {
    my ($self) = @_;
    my $setname = $self->setname;
    my @lines = pf_run("sudo ipset list $setname 2>/dev/null", accepted_exit_status => [1]);

    while (my $line = shift @lines) {
        last if $line =~ /Members:/;
    }
    my @pairs;
    while (my $line = shift @lines) {
        unless ($line =~ /(\d+(?:\.\d+){3}),((?:tcp|udp):(?:\d+))/) {
            $logger->error("Could not match line : '$line'");
            next;
        }
        push @pairs, { ip => $1, port => $2}
    }
    $self->_add_pairs_to_cache(\@pairs);
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
