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
        get_all_perl_binaries get_all_perl_cgi get_all_perl_modules 
        get_all_php
        get_networkdevices_modules get_networkdevices_classes
    );
}

use pf::config;

# Tests are categorized here
our @cli_tests = qw(
    pfcmd.t pfcmd_vlan.t pfdhcplistener.t
);

our @compile_tests = qw(
    pf.t binaries.t php.t
);

our @dao_tests = qw(
    dao/data.t dao/graph.t dao/node.t dao/os.t dao/person.t dao/report.t
);

our @integration_tests = qw(
    integration.t integration/captive-portal.t integration/pfcmd.t integration/Portal.t integration/radius.t
);

our @quality_tests = qw(
    coding-style.t pod.t i18n.t
);

our @quality_failing_tests = qw(
    critic.t podCoverage.t
);

our @unit_tests = qw(
    config.t enforcement.t floatingdevice.t hardware-snmp-objects.t import.t inline.t linux.t network-devices/cisco.t 
    network-devices/roles.t network-devices/threecom.t network-devices/wireless.t nodecategory.t person.t pfsetvlan.t 
    Portal.t radius.t services.t SNMP.t soh.t SwitchFactory.t trigger.t useragent.t util.t util-dhcp.t util-radius.t
    vlan.t web.t web-auth.t
);

our @unit_failing_tests = qw(
    network-devices/wired.t
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

=item get_all_perl_binaries

Return all the files ending with .pl under

  /usr/local/pf/addons
  /usr/local/pf/lib/pf

and return all the normal files under

  /usr/local/pf/bin
  /usr/local/pf/sbin


=cut
sub get_all_perl_binaries {

    my @list;

    # find2perl /usr/local/pf/lib/pf /usr/local/pf/addons -name "*.pl"
    # Except that I'm explicitly throwing out addons/legacy/...
    File::Find::find({
        wanted => sub {
            /^.*\.pl\z/s 
            && $File::Find::name !~ /^.*addons\/legacy\/.*\.pl\z/s
            && push(@list, $File::Find::name);
        }}, '/usr/local/pf/lib/pf', '/usr/local/pf/addons'
    );

    # find2perl /usr/local/pf/bin /usr/local/pf/sbin -type f
    File::Find::find({
        wanted => sub {
            # add to list if it's a regular file
            push(@list, $File::Find::name) if ((-f $File::Find::name) && ($File::Find::name ne "/usr/local/pf/bin/pfcmd")); 
        }}, '/usr/local/pf/bin', '/usr/local/pf/sbin'
    );


    return @list;
}

=item get_all_perl_cgi

Return all the files ending with .cgi under

  /usr/local/pf/html

=cut
sub get_all_perl_cgi {

    my @list;

    # find2perl /usr/local/pf/html -name "*.cgi"
    File::Find::find({
        wanted => sub {
            /^.*\.cgi\z/s && push(@list, $File::Find::name);
        }}, '/usr/local/pf/html'
    );

    return @list;
}

=item get_all_perl_modules

Return all the files ending with .pm under

  /usr/local/pf/addons
  /usr/local/pf/conf/authentication
  /usr/local/pf/lib/pf

One exception: pfcmd_pregrammar.pm because it's generated

=cut
sub get_all_perl_modules {

    my @list;

    # find2perl /usr/local/pf/lib/pf /usr/local/pf/addons -name "*.pm"
    # Except that I'm explictly throwing out pfcmd_pregrammar.pm and anything in addons/legacy/
    File::Find::find({
        wanted => sub {
            /^.*\.pm\z/s 
            && ! /^.*pfcmd_pregrammar\.pm\z/s 
            && $File::Find::name !~ /^.*addons\/legacy\/.*\.pm\z/s
            && push(@list, $File::Find::name);
        }}, '/usr/local/pf/lib/pf', '/usr/local/pf/conf/authentication', '/usr/local/pf/addons'
    );

    return @list;
}

=item get_all_php

Return all the files ending with .php or .inc under F</usr/local/pf/html>

=cut
sub get_all_php {

    my @list;

    # find2perl  /usr/local/pf/html -name "*.php" -o -name "*.inc"
    File::Find::find({
        wanted => sub {
           /^.*\.php\z/s || /^.*\.inc\z/s && push(@list, $File::Find::name);
        }}, '/usr/local/pf/html'
    );

    return @list;
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
        
Copyright (C) 2011, 2012 Inverse inc.

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
