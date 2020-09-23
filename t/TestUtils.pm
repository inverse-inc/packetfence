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
use FindBin qw($Bin);

BEGIN {
    use Exporter ();
    our ( @ISA, @EXPORT_OK );
    @ISA = qw(Exporter);
    @EXPORT_OK = qw(
        @cli_tests @compile_tests @dao_tests @integration_tests @quality_tests @quality_failing_tests @unit_tests
        use_test_db
        get_all_perl_binaries get_all_perl_cgi get_all_perl_modules
        get_networkdevices_modules get_networkdevices_classes cpuinfo
    );
}
use pf::config qw(%Config);

# Tests are categorized here
our @cli_tests = qw(
    pfcmd.t pfcmd_vlan.t pfdhcplistener.t
);

our @compile_tests = qw(
    pf.t template.t
);

our @slow_compile_tests = qw(
    pf-slow.t pfappserver_libs-slow.t captive-portal_libs-slow.t template.t
);

our @dao_tests = qw(
    dao/data.t dao/graph.t dao/node.t dao/os.t dao/person.t dao/report.t
);

our @integration_tests = qw(
    integration.t integration/captive-portal.t integration/pfcmd.t integration/Portal.t integration/radius.t
);

our @quality_tests = qw(
    coding-style.t i18n.t
);

our @quality_failing_tests = qw(
    critic.t podCoverage.t
);

our @unit_tests = qw(
    config.t enforcement.t floatingdevice.t hardware-snmp-objects.t import.t inline.t linux.t network-devices/cisco.t
    network-devices/roles.t network-devices/threecom.t network-devices/wireless.t nodecategory.t person.t
    Portal.t radius.t services.t SNMP.t SwitchFactory.t util.t util-dhcp.t util-radius.t
    role.t web.t
);

our @unit_failing_tests = qw(
    network-devices/wired.t
);

=head2 get_compile_tests

get_compile_tests

=cut

sub get_compile_tests {
    my ($slow) = @_;
    return $slow ? @slow_compile_tests : @compile_tests ;
}

=head2 use_test_db

Will override pf::config's globals regarding what database to connect to

=cut

sub use_test_db {

    # override database connection settings
    $Config{'database'}{'host'} = '127.0.0.1';
    $Config{'database'}{'user'} = 'pf-test';
    $Config{'database'}{'pass'} = 'p@ck3tf3nc3';
    $Config{'database'}{'db'} = 'pf-test';
}

=head2 get_all_perl_binaries

Return all the files ending with .pl under

  /usr/local/pf/addons
  /usr/local/pf/lib/pf

and return all the normal files under

  /usr/local/pf/bin
  /usr/local/pf/sbin


=cut

my %exclusions = map { $_ => 1 } qw(
   /usr/local/pf/bin/pfcmd
   /usr/local/pf/sbin/pfacct
   /usr/local/pf/sbin/pfcertmanager
   /usr/local/pf/sbin/pfhttpd
   /usr/local/pf/sbin/pfdns
   /usr/local/pf/sbin/pfdhcp
   /usr/local/pf/sbin/pfipset
   /usr/local/pf/sbin/pfcron
   /usr/local/pf/sbin/pfstats
   /usr/local/pf/sbin/pfdetect
   /usr/local/pf/bin/ntlm_auth_wrapper
   /usr/local/pf/addons/sourcefire/pfdetect.pl
   /usr/local/pf/sbin/galera-autofix
);

sub get_all_perl_binaries {

    my @list;

    # find2perl /usr/local/pf/lib/pf /usr/local/pf/addons -name "*.pl"
    # Except that I'm explicitly throwing out addons/legacy/...
    File::Find::find({
        wanted => sub {
            /^.*\.pl\z/s
            && $File::Find::name !~ /^.*addons\/legacy\/.*\.pl\z/s
            && push(@list, $File::Find::name) if not exists $exclusions{ $File::Find::name } ;
        }}, '/usr/local/pf/lib/pf', '/usr/local/pf/addons'
    );

    # find2perl /usr/local/pf/bin /usr/local/pf/sbin -type f
    File::Find::find({
        wanted => sub {
            # add to list if it's a regular file
            my $name = $File::Find::name;
            push(@list, $name) if ((-f $name) &&
                (not exists $exclusions{ $name }) && $_ !~ /^\./ );
        }}, '/usr/local/pf/bin', '/usr/local/pf/sbin'
    );


    return @list;
}

=head2 get_all_perl_cgi

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

=head2 get_all_perl_modules

Return all the files ending with .pm under

  /usr/local/pf/addons
  /usr/local/pf/conf/authentication

=cut

sub get_all_perl_modules {

    my @list;

    # find2perl /usr/local/pf/lib/pf /usr/local/pf/addons -name "*.pm"
    # Except that I'm explictly throwing out anything in addons/legacy/
    File::Find::find({
        wanted => sub {
            /^.*\.pm\z/s
            && $File::Find::name !~ /^.*addons\/legacy\/.*\.pm\z/s
            && push(@list, $File::Find::name);
        }}, '/usr/local/pf/lib/pf', '/usr/local/pf/addons'
    );

    return @list;
}

=head2 get_networkdevices_modules

Return all the files ending with .pm under /usr/local/pf/lib/pf/Switch

=cut

sub get_networkdevices_modules {

    my @list;
    push (@list, '/usr/local/pf/lib/pf/Switch.pm');

    # find2perl /usr/local/pf/lib/pf/Switch -name "*.pm"
    File::Find::find({
        wanted => sub {
            /^.*\.pm\z/s && push(@list, $File::Find::name);
        }}, '/usr/local/pf/lib/pf/Switch'
    );

    return @list;
}

=head2 get_all_unittests

Return all the files /usr/loca/pf/t/unitest

=cut

sub get_all_unittests {

    my @list;

    # find2perl /usr/local/pf/lib/pf/Switch -name "*.pm"
    File::Find::find({
        wanted => sub {
            if ($File::Find::name =~ m#^\Q$Bin\E/unittest/(.*\.t)$# ) {
                push(@list, "unittest/$1");
            }
        }}, "$Bin/unittest"
    );
    return @list;
}

=head2 get_all_serialized_unittests

Return all the files /usr/local/pf/t/serialized_unittests

=cut

sub get_all_serialized_unittests {

    my @list;

    # find2perl /usr/local/pf/lib/pf/Switch -name "*.pm"
    File::Find::find({
        wanted => sub {
            if ($File::Find::name =~ m#^\Q$Bin\E/serialized_unittests/(.*\.t)$# ) {
                push(@list, "serialized_unittests/$1");
            }
        }}, "$Bin/serialized_unittests"
    );
    return @list;
}

=head2 get_networkdevices_classes

Return the pf::Switch::Device form for all modules under /usr/local/pf/lib/pf/Switch except constants.pm and Generic.pm

=cut

sub get_networkdevices_classes {

    my @modules = get_networkdevices_modules();
    my @classes;
    foreach my $module (@modules) {
        # skip constants.pm and Generic.pm
        next if ($module =~ /constants\.pm$/ || $module =~ /Generic\.pm$/);
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

sub cpuinfo {
    my @cpuinfos;
    if (open(my $fh, "/proc/cpuinfo")) {
        while (my $l = <$fh>) {
            chomp($l);
            if ($l =~ /(.*?)\s*: (.*)/) {
                my $n = $1;
                if ($n eq 'processor') {
                    push @cpuinfos, {};
                }
                $cpuinfos[-1]{$n} = $2;
            }
        }
    }
    return \@cpuinfos;
}

=head1 AUTHOR

Inverse inc. <info@inverse.ca>

=head1 COPYRIGHT

Copyright (C) 2005-2020 Inverse inc.

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
