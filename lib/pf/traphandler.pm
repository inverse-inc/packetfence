package pf::traphandler;
=head1 NAME

pf::traphandler 

=cut

=head1 DESCRIPTION

Acts on SNMP traps and set switch port VLAN according to
the discovered MACs status in packetfence.

=cut

use strict;
use warnings;
use pf::log;
use pf::SwitchFactory;
use pf::vlan::custom;
use pf::trap;

sub handleTrap {
    my ($self,$trapInfo,$oids) = @_;
    my $logger = pf::log::get_logger();
    my $switch = pf::SwitchFactory->instantiateFromTrap($trapInfo);
    return unless $switch;
    my $trap = $switch->parseTrapEvent($trapInfo,$oids);
    return if $trap->isa('pf::trap::unknown');
    my $trapMac = $trap->mac;
    my $trapType = $trap->type;

    # do we actually act on this trap ?
    if ( defined($trapMac) && $switch->isFakeMac($trapMac) ) {
        $logger->info("MAC $trapMac is a fake MAC. Stop $trapType handling");
        return;
    }
    my $switch_port = $trap->switchPort;
    my $vlan_obj = new pf::vlan::custom();
    my $weActOnThisTrap = $vlan_obj->doWeActOnThisTrap($switch, $switch_port, $trapType);

    if ( $weActOnThisTrap == 0 ) {
        $logger->info("doWeActOnThisTrap returns false. Stop $trapType handling");
        return;
    }
    my $switch_id = $switch->{_id};
    $logger->info("$trapType trap received on $switch_id ifIndex $switch_port");
    $trap->handle();
}

=head1 AUTHOR

Inverse inc. <info@inverse.ca>

=head1 COPYRIGHT

Copyright (C) 2005-2013 Inverse inc.

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

# vim: set shiftwidth=4:
# vim: set expandtab:
# vim: set backspace=indent,eol,start:
# vim: set foldmethod=marker:
# vim: set foldcolumn=4:
 
=head1 AUTHOR

Inverse inc. <info@inverse.ca>

=head1 COPYRIGHT

Copyright (C) 2005-2014 Inverse inc.

=head1 LICENSE

This program is free software; you can redistribute it and::or
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

