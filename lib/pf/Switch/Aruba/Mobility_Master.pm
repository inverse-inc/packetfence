package pf::Switch::Aruba::Mobility_Master;

=head1 NAME

pf::Switch::Aruba::Mobility_Master - Object oriented module to access Aruba Mobility Master

=head1 SYNOPSIS

The pf::Switch::Aruba::Mobility_master module implements an object oriented interface
to access Mobility Master

=cut

use strict;
use warnings;

use base ('pf::Switch::Aruba');

use pf::util;

use NetAddr::IP;

sub description { 'Aruba Mobility Master' }

use pf::SwitchSupports qw(
    PushACLs
    AccessListBasedEnforcement
);

=head2 acl_chewer

Format ACL to match with the expected switch format.

=cut

sub acl_chewer {
    my ($self, $acl, $role) = @_;
    my $logger = $self->logger;
    my ($acl_ref , @direction) = $self->format_acl($acl);

    my $i = 0;
    my @acl_chewed;
    foreach my $acl (@{$acl_ref->{'packetfence'}->{'entries'}}) {
        my $new_acl;
        #Bypass acl that contain tcp_flag, it doesnt apply correctly on the switch
        next if (defined($acl->{'tcp_flags'}));
        $acl->{'protocol'} =~ s/\(\d*\)//;
        $new_acl->{'protocol'} = $acl->{'protocol'};
        my $dest;
        my $dest_port;
        if (defined($acl->{'destination'}->{'port'})) {
            $new_acl->{'dst_port'} = $acl->{'destination'}->{'port'};
            if ($new_acl->{'dst_port'} =~ /range\s+(.*)/) {
                $new_acl->{'range'} = "true";
                $new_acl->{'dst_port'} = $1;
                $new_acl->{'dst_port'} =~ s/\s/-/;
                ($new_acl->{'dst_port'}, $new_acl->{'dst_port2'}) = split(/-/, $new_acl->{'dst_port'});
            } else {
                $new_acl->{'range'} = "false";
                $new_acl->{'dst_port'} =~ s/\w+\s+//;
            }
        } else {
            if ($new_acl->{'protocol'} =~ /^(tcp|udp)$/) {
                $new_acl->{'range'} = "true";
                $new_acl->{'dst_port'} = "0";
                $new_acl->{'dst_port2'} = "65535";
            }
        }
        if ($acl->{'destination'}->{'ipv4_addr'} eq '0.0.0.0') {
           $new_acl->{'dst'} = "any";
           $new_acl->{'dst_object'} = "dany";
        } elsif($acl->{'destination'}->{'ipv4_addr'} ne '0.0.0.0') {
            if ($acl->{'destination'}->{'wildcard'} ne '0.0.0.0') {
                $new_acl->{'dst_network'} = $acl->{'destination'}->{'ipv4_addr'};
                $new_acl->{'dst_netmask'} = norm_net_mask($acl->{'destination'}->{'wildcard'});
                $new_acl->{'dst_object'} = "dnetwork";
            } else {
                $new_acl->{'dst_object'} = "dhost";
                $new_acl->{'dst_ipaddr'} = $acl->{'destination'}->{'ipv4_addr'};
            }
        }
        my $src;
        if ($acl->{'source'}->{'ipv4_addr'} eq '0.0.0.0') {
            $new_acl->{'src'} = "suser";
            $new_acl->{'suser'} = "true";
        } elsif($acl->{'source'}->{'ipv4_addr'} ne '0.0.0.0') {
            if ($acl->{'source'}->{'wildcard'} ne '0.0.0.0') {
                my $net_addr = NetAddr::IP->new($acl->{'source'}->{'ipv4_addr'}, norm_net_mask($acl->{'source'}->{'wildcard'}));
                my $cidr = $net_addr->cidr();
                $new_acl->{'src'} = $cidr;
            } else {
                $new_acl->{'src'} = $acl->{'source'}->{'ipv4_addr'};
            }
        }
        my $j = $i + 1;
        if ($self->usePushACLs && (whowasi() eq "pf::Switch::getRoleAccessListByName")) {
            $new_acl->{'dir_prefix'} = (defined($direction[$i]) && $direction[$i] ne "") ? $direction[$i] . "|" : "";
            $new_acl->{'src'}    = ($self->usePushACLs) ? $new_acl->{'src'} : "any";
            $new_acl->{'dst_port'} = defined($new_acl->{'dst_port'}) ? $new_acl->{'dst_port'} : '';
            $new_acl->{'action'} = $acl->{'action'};
            push @acl_chewed , $new_acl;
        }
        $i++;
    }
    return \@acl_chewed;
}

=head2 implicit_acl

Return implicit acl

=cut

sub implicit_acl {
    my ($self) = @_;
    return "permit any";
}

=head1 AUTHOR

Inverse inc. <info@inverse.ca>

=head1 COPYRIGHT

Copyright (C) 2005-2025 Inverse inc.

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
