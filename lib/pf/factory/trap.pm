package pf::factory::trap;
=head1 NAME

pf::factory::trap add documentation

=cut

=head1 DESCRIPTION

pf::factory::trap

=cut

use strict;
use warnings;
use pf::SwitchFactory;
use Module::Pluggable
  'search_path' => [qw(pf::trap)],
  'sub_name'    => 'modules',
  'require'     => 1,
  ;
use List::Util qw(first);
use List::MoreUtils qw(any);

our @MODULES = __PACKAGE__->modules;

our %OID_TO_MODULE;

foreach my $module (@MODULES) {
    next unless $module->can('supportedOIDS');
    foreach my $oid ($module->supportedOIDS) {
        $OID_TO_MODULE{$oid} = $module;
    }
}

sub factory_for {'pf::trap'}

sub instantiate {
    my ($class, $trapInfo, $oids) = @_;
    my $object;
    my $data = $class->getData($trapInfo, $oids);
    if ($data) {
        my $subclass = $class->getModuleName($data);
        $object = $subclass->new($data);
    }
    return $object;
}

sub getModuleName {
    my ($class, $data) = @_;
    my $mainClass = $class->factory_for;
    my $subclass  = $data->{type};
    die "type is not defined" unless defined $subclass;
    die "$subclass is not a valid type" unless any {$_ eq $subclass} @MODULES;
    $subclass;
}

sub getData {
    my ($class, $trapInfo, $oids) = @_;
    my $switch = $class->switchTrapInfo($trapInfo);
    return unless $switch;
    my $trapOid = $class->trapModuleForOid($oids);
    return unless $trapOid && exists $OID_TO_MODULE{$trapOid};
    my $type = $OID_TO_MODULE{$trapOid};
    return { type => $type, 'switch' => $switch, 'trapInfo' => $trapInfo, 'oids' => $oids };
}

sub trapModuleForOid {
    my ($class,$oids) = @_;
    my $oid = first { $_->[0] eq '.1.3.6.1.6.3.1.1.4.1.0' } @$oids;
    if( $oid && $oid->[2] == 6 && $oid->[1] =~ /^OID: (.*)$/ ) {
        return $1;
    }
    return;
}

sub switchTrapInfo {
    my ($class,$trapInfo) = @_;
    my $receivedFromData = $class->parseReceivedFrom($trapInfo);
    return pf::SwitchFactory->instantiate($receivedFromData->{networkDeviceIp});
}

=head2 parseReceivedFrom

=cut

sub parseReceivedFrom {
    my ($self,$trapInfo) = @_;
    $trapInfo->{receivedfrom} =~ m/
    (?:UDP:\ \[)?                                       # Optional "UDP: [" (since v2 traps I think)
    (\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3})                # network device ip address
    (?:\]:(\d+))?                                         # Optional "]:port" (since v2 traps I think)
    (?:\-\>\[(\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3})\])?     # Optional "->[ip address]" (since net-snmp 5.4)
    /x;
    my $receivedFromData = {
        networkDeviceIp => $1,
        port => $2,
        optIpAddress => $3,
    };
    return $receivedFromData;
}
 
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

