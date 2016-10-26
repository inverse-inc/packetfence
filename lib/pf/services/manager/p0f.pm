package pf::services::manager::p0f;

=head1 NAME

pf::services::manager::p0f management module.

=cut

=head1 DESCRIPTION

pf::services::manager::p0f

=cut

use strict;
use warnings;
use Moo;
use fingerbank::Config;
use pf::config qw(@ha_ints);

extends 'pf::services::manager';

has '+name' => ( default => sub {'p0f'} );
has '+optional' => ( default => sub {1} );

has '+launcher' => (
    default => sub {
        my ($self) = @_;
        my $FingerbankConfig = fingerbank::Config::get_config;
        my $p0f_map = $FingerbankConfig->{tcp_fingerprinting}{p0f_map_path};
        my $p0f_sock = $FingerbankConfig->{tcp_fingerprinting}{p0f_socket_path};
        my $pid_file = $self->pidFile;
        my $name = $self->name;
        my $p0f_cmdline;
        if (@ha_ints)
        {
            my @ha_ips;
            foreach my $ha_int (@ha_ints)
            {
                push (@ha_ips, $ha_int->{Tip});
            }
            my @tmp_bpf_filter = map { "not ( host $_ and port 7788 )"} @ha_ips;
            my $p0f_bpf_filter = join(" and ", @tmp_bpf_filter);
            $p0f_cmdline="sudo %1\$s -d -i any -p -f $p0f_map -s $p0f_sock" . " '$p0f_bpf_filter' " . " > /dev/null && pidof $name > $pid_file";
        }
        else
        {
            $p0f_cmdline="sudo %1\$s -d -i any -p -f $p0f_map -s $p0f_sock > /dev/null && pidof $name > $pid_file";    
        }
        return $p0f_cmdline;
    }
);

sub preStartSetup {
    my ($self, $quickStart) = @_;
    my $result = $self->SUPER::preStartSetup($quickStart);
    local ($!, $?);
    system("pkill p0f");
    return $result;
}

=head1 AUTHOR

Inverse inc. <info@inverse.ca>

=head1 COPYRIGHT

Copyright (C) 2005-2016 Inverse inc.

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
