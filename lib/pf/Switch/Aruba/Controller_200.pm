package pf::Switch::Aruba::Controller_200;

=head1 NAME

pf::Switch::Aruba::Controller_200 - Object oriented module to access SNMP enabled Aruba Controller 200

=head1 SYNOPSIS

The pf::Switch::Aruba::Controller_200 module implements an object oriented interface
to access SNMP enabled Aruba Controller 200

=cut

use strict;
use warnings;

use base ('pf::Switch::Aruba');
use pf::util;

use NetAddr::IP;

sub description { 'Aruba 200 Controller' }

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
    my $acl_chewed;
    foreach my $acl (@{$acl_ref->{'packetfence'}->{'entries'}}) {
        #Bypass acl that contain tcp_flag, it doesnt apply correctly on the switch
        next if (defined($acl->{'tcp_flags'}));
        $acl->{'protocol'} =~ s/\(\d*\)//;
        my $dest;
        my $dest_port;
        if (defined($acl->{'destination'}->{'port'})) {
            $dest_port = $acl->{'destination'}->{'port'};
            if ($dest_port =~ /range\s+(.*)/) {
                $dest_port = $1;
                $dest_port =~ s/\s/-/;
            } else {
                $dest_port =~ s/\w+\s+//;
            }
        }
        if ($acl->{'destination'}->{'ipv4_addr'} eq '0.0.0.0') {
            $dest = "any";
        } elsif($acl->{'destination'}->{'ipv4_addr'} ne '0.0.0.0') {
            if ($acl->{'destination'}->{'wildcard'} ne '0.0.0.0') {
                my $net_addr = NetAddr::IP->new($acl->{'destination'}->{'ipv4_addr'}, norm_net_mask($acl->{'destination'}->{'wildcard'}));
                my $cidr = "network ".$net_addr->cidr();
                $dest = $cidr;
            } else {
                $dest = "host ".$acl->{'destination'}->{'ipv4_addr'};
            }
        }
        my $src;
        if ($acl->{'source'}->{'ipv4_addr'} eq '0.0.0.0') {
            $src = "any";
        } elsif($acl->{'source'}->{'ipv4_addr'} ne '0.0.0.0') {
            if ($acl->{'source'}->{'wildcard'} ne '0.0.0.0') {
                my $net_addr = NetAddr::IP->new($acl->{'source'}->{'ipv4_addr'}, norm_net_mask($acl->{'source'}->{'wildcard'}));
                my $cidr = $net_addr->cidr();
                $src = $cidr;
            } else {
                $src = $acl->{'source'}->{'ipv4_addr'};
            }
        }
        my $j = $i + 1;
        if ($self->usePushACLs && (whowasi() eq "pf::Switch::getRoleAccessListByName")) {
            my $dir_prefix = (defined($direction[$i]) && $direction[$i] ne "") ? $direction[$i] . "|" : "";
            my $src_val    = ($self->usePushACLs) ? $src : "any";
            my $dest_port_val = defined($dest_port) ? $dest_port : '';
            my $line = sprintf("%s %s %s %s %s %s\n",
                $dir_prefix,
                $src_val,
                $dest,
                $acl->{'protocol'},
                $dest_port_val,
                $acl->{'action'}
            );
            $acl_chewed .= $line;
        } else {
            $acl_chewed .= ((defined($direction[$i]) && $direction[$i] ne "") ? $direction[$i]."|" : "").$acl->{'action'}." ".((defined($direction[$i]) && $direction[$i] ne "") ? $direction[$i] : "in")." ".$acl->{'protocol'}." from any to ".$dest." ".( defined($dest_port) ? $dest_port : '' )."\n";
        }
        $i++;
    }
    return $acl_chewed;
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
