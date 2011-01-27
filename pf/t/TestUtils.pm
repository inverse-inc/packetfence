package TestUtils;

=head1 NAME

TestUtils

=head1 DESCRIPTION

Various utilities to reduce code duplication in testing.

=cut

BEGIN {
    use Exporter ();
    our ( @ISA, @EXPORT );
    @ISA = qw(Exporter);
    @EXPORT_OK = qw(
        @cli_tests @compile_tests @dao_tests @integration_tests @quality_tests @quality_failing_tests @unit_tests 
    );
}

# Tests are categorized here
our @cli_tests = qw(
    pfcmd.t
);

our @compile_tests = qw(
    binaries.t
    pf.t 
    php.t
);

our @dao_tests = qw(
    dao/person.t
);

our @integration_tests = qw(
    integration.t
);

our @quality_tests = qw(
    coding-style.t
    pod.t
);

our @quality_failing_tests = qw(
    critic.t
    podCoverage.t
);

our @unit_tests = qw(
    config.t
    data.t
    floatingdevice.t
    graph.t
    hardware-snmp-objects.t
    import.t
    network-devices/cisco.t
    node.t
    nodecategory.t
    person.t 
    pfsetvlan.t
    radius.t
    report.t
    services.t
    SNMP.t 
    SwitchFactory.t
    util.t
    vlan.t
);

=head1 AUTHOR

Olivier Bilodeau <obilodeau@inverse.ca>
        
=head1 COPYRIGHT
        
Copyright (C) 2011 Inverse inc.

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
