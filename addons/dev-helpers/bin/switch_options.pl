#!/usr/bin/perl

=head1 NAME

switch_options -

=head1 DESCRIPTION

switch_options

=cut

use strict;
use warnings;
use lib qw(/usr/local/pf/lib);
use lib qw(/usr/local/pf/lib_perl/lib/perl5);
use Pod::Select;
use Pod::Find qw(pod_where);
use Data::Dumper;
use pf::SwitchFactory;

#
# Extract and prepare the data
#
#

pf::SwitchFactory->preloadAllModules();
my @groups = pf::SwitchFactory::form_options();

my %dict_name_infos=();
for my $g (@groups) {
    for my $switch_info (@{$g->{options}}) {
        my $string="";

        my $name = $switch_info->{value};
        my $module = "pf::Switch::${name}";
        $switch_info->{related} = getRelated($module);
        if (not $switch_info->{is_template}) {
            my $file = pod_where({-inc => 1}, $module);
            my $snmp = '';
            open(my $fh, ">", \$snmp);
            podselect({-sections=>["SNMP"], -output => $fh}, $file);
            if ($snmp ne '') {
                $switch_info->{snmptrap}="true";
            }
            close($fh);
        }
        my $aSupports= $switch_info->{supports};
        my $supports = join( ',', @$aSupports);
        if ($supports =~ /VPN/) {
          $switch_info->{"vpn"}="true";
        } elsif ($supports =~ /Wired/ && $supports =~ /Wireless/){
          $switch_info->{"wired_wireless"}="true";
        } elsif ($supports =~ /Wireless/){
          $switch_info->{"wireless"}="true";
        } elsif ($supports =~ /Wired/ || $supports =~ /RadiusDynamicVlanAssignment/){
          $switch_info->{"wired"}="true";
        } else {
          print("$name \t$supports\n");
        }
        $switch_info->{"WiredMacAuth"}="true"                if ($supports =~ /WiredMacAuth/ && $supports !~ /-WiredMacAuth/) ;
        $switch_info->{"WiredDot1x"}="true"                  if ($supports =~ /WiredDot1x/ && $supports !~ /-WiredDot1x/) ;
        $switch_info->{"RadiusDynamicVlanAssignment"}="true" if ($supports =~ /RadiusDynamicVlanAssignment/ && $supports !~ /-RadiusDynamicVlanAssignment/) ;
        $switch_info->{"ExternalPortal"}="true"              if ($supports =~ /ExternalPortal/ && $supports !~ /-ExternalPortal/) ;
        $switch_info->{"MABFloatingDevices"}="true"          if ($supports =~ /MABFloatingDevices/ && $supports !~ /-MABFloatingDevices/) ;
        $switch_info->{"WebFormRegistration"}="true"         if ($supports =~ /WebFormRegistration/ && $supports !~ /-WebFormRegistration/) ;
        $switch_info->{"AccessListBasedEnforcement"}="true"  if ($supports =~ /AccessListBasedEnforcement/ && $supports !~ /-AccessListBasedEnforcement/) ;
        $switch_info->{"RadiusVoip"}="true"                  if ($supports =~ /RadiusVoip/ && $supports !~ /-RadiusVoip/) ;
        $switch_info->{"FloatingDevice"}="true"              if ($supports =~ /FloatingDevice/ && $supports !~ /-FloatingDevice/) ;
        $switch_info->{"Cdp"}="true"                         if ($supports =~ /Cdp/ && $supports !~ /-Cdp/) ;
        $switch_info->{"Lldp"}="true"                        if ($supports =~ /Lldp/ && $supports !~ /-Lldp/) ;
        $switch_info->{"RoamingAccounting"}="true"           if ($supports =~ /RoamingAccounting/ && $supports !~ /-RoamingAccounting/) ;
        $switch_info->{"SaveConfig"}="true"                  if ($supports =~ /SaveConfig/ && $supports !~ /-SaveConfig/) ;
        $switch_info->{"SNMP"}="true"                        if ($supports =~ /SNMP/ && $supports !~ /-SNMP/) ;
        $dict_name_infos{$name}=$switch_info
    }
}

#
# Create the table
#
my $t2='  ';
my $t4='    ';
my $tab=$t4.$t2.'<tr id="';
foreach my $key (keys %dict_name_infos) {
  my $switch_info = $dict_name_infos{$key};
  #print "  $key => $switch_info->{value}\n";
  if ($switch_info->{"WiredMacAuth"}) {
    print "  $key => $switch_info->{value}\n";
  }
}

#
# create the html page
#

my $html='
<div>
  <strong>Filter:</strong>
  <input type="text" style="width:100%" id="filter"/>
  <input type="reset"/>
</div>


<table id="switches">
  <thead>
    <th>
      <td>Switch</td>
      <td>SNMP</td>
      <td>MAC Authentication</td>
      <td>802.1X</td>
      <td>Web Auth</td>
    </th>
  </thead>
';

#$html+=$printVPN
#$html+=$printWireWireless
#$html+=$printWired
#$html+=$printWireless

$html.='
  </tbody>
</table>

<script>
window.on("load", () => {
  $("#filter").on("change", () => { // change or input
    $("#switches").tbody.find(row where id like "filter").style({ display: "block" | "none" })
  })
})

// search test
var test = "teststring"
console.log( test.includes("foo") ) // false
console.log( test.includes("str") ) // true
console.log( test.includes("STR") ) // false

test.toLowerCase().includes("STR".toLowerCase()) // true
</script>';



sub getRelated {
    my ($m) = @_;
    no strict qw(refs);
    my $p =return *{"${m}::ISA"}->[-1];
    $p =~ s/pf::Switch:://;
    return $p;
}

=head1 AUTHOR

Inverse inc. <info@inverse.ca>

=head1 COPYRIGHT

Copyright (C) 2005-2021 Inverse inc.

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
