package TestUtils;

=head1 NAME

TestUtils

=head1 DESCRIPTION

Various utilities to reduce code duplication in testing.

=cut

use strict;
use warnings;
use diagnostics;

use lib '/usr/local/pf/lib';
use File::Find;

BEGIN {
    use Exporter ();
    our ( @ISA, @EXPORT_OK );
    @ISA = qw(Exporter);
    @EXPORT_OK = qw(
        @cli_tests @compile_tests @dao_tests @integration_tests @quality_tests @quality_failing_tests @unit_tests 
        use_test_db
        get_networkdevices_modules get_networkdevices_classes
    );
}

use pf::config;

# Tests are categorized here
our @cli_tests = qw(
    pfcmd.t pfdhcplistener.t
);

our @compile_tests = qw(
    binaries.t pf.t php.t
);

our @dao_tests = qw(
    dao/data.t dao/graph.t dao/node.t dao/person.t dao/report.t
);

our @integration_tests = qw(
    integration.t integration/radius.t integration/captive-portal.t
);

our @quality_tests = qw(
    coding-style.t pod.t
);

our @quality_failing_tests = qw(
    critic.t podCoverage.t
);

our @unit_tests = qw(
    config.t enforcement.t floatingdevice.t hardware-snmp-objects.t import.t inline.t linux.t network-devices/cisco.t 
    network-devices/threecom.t network-devices/wireless.t nodecategory.t person.t pfsetvlan.t radius.t services.t 
    SNMP.t SwitchFactory.t trigger.t useragent.t util.t vlan.t web.t web-auth.t
);

=item use_test_db

Will override pf::config's globals regarding what database to connect to

=cut
sub use_test_db {

    # override database connection settings
    $Config{'database'}{'host'} = '127.0.0.1';
    $Config{'database'}{'user'} = 'pf-test';
    $Config{'database'}{'pass'} = 'p@ck3tf3nc3';
    $Config{'database'}{'db'} = 'pf-test';
}

=item get_networkdevices_modules

Return all the files ending with .pm under /usr/local/pf/lib/pf/SNMP

=cut
sub get_networkdevices_modules {

    my @list;
    push (@list, '/usr/local/pf/lib/pf/SNMP.pm');

    # find2perl /usr/local/pf/lib/pf/SNMP -name "*.pm"
    File::Find::find({
        wanted => sub {
            /^.*\.pm\z/s && push(@list, $File::Find::name);
        }}, '/usr/local/pf/lib/pf/SNMP'
    );

    return @list;
}

=item get_networkdevices_classes

Return the pf::SNMP::Device form for all modules under /usr/local/pf/lib/pf/SNMP except constants.pm

=cut
sub get_networkdevices_classes {

    my @modules = get_networkdevices_modules();
    my @classes;
    foreach my $module (@modules) {
        # skip constants.pm
        next if $module =~ /constants\.pm$/;
        # get rid of path
        $module =~ s|^/usr/local/pf/lib/||;
        # get rid of ending .pm
        $module =~ s|\.pm$||;
        # change slashes for ::
        $module =~ s|/|::|g;
        push(@classes, $module);
    }
    return @classes;
}

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
