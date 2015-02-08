#!/usr/bin/perl
=head1 NAME

config-cached add documentation

=cut

=head1 DESCRIPTION

config-cached

=cut

use strict;
use warnings;
# pf core libs
use lib '/usr/local/pf/lib';
use File::Path qw(remove_tree);
use File::Temp qw(tempfile);
use File::Copy;
use Scalar::Util qw(refaddr);
use File::Slurp qw(read_file);
use POSIX ":sys_wait_h";

our (%DATA,%DATA1,%DATA2,%DATA3,$filename);

BEGIN {
    use lib qw(/usr/local/pf/t);
    use PfFilePaths;
}
use pf::log;

use Test::More tests => 17;

use Test::NoWarnings;
use Test::Exception;

use_ok("pf::config::cached");

(undef, $filename) = tempfile(OPEN => 0,UNLINK => 0);

copy("/usr/local/pf/t/data/test.conf",$filename);

my $onreload_count = 0;
my $onfilereload_count = 0;
my $oncachereload_count = 0;
my $onpostreload_count = 0;

my $config =  pf::config::cached->new(
    -file => $filename,
    -onreload => [
        reload => sub {
            my ($config,$name) = @_;
            $config->toHash(\%DATA1);
            $onreload_count++;
        }
    ],
    -onfilereload => [
        reload => sub {
            my ($config,$name) = @_;
            $config->cache->set("DATA2",\%DATA1);
            $onfilereload_count++;
        }
    ],
    -oncachereload => [
        reload => sub {
            my ($config,$name) = @_;
            %DATA2 = %{$config->cache->get("DATA2")};
            $oncachereload_count++;
        }
    ],
    -onpostreload => [
        reload => sub {
            my ($config,$name) = @_;
            $config->toHash(\%DATA3);
        }
    ],
);

isa_ok($config,"pf::config::cached");

isa_ok($config,"Config::IniFiles","Pretending to be a Config::IniFiles");

ok(exists $DATA1{section1},"\$config->toHash");


ok($DATA1{section1}{param1} eq 'value1',"\$config->toHash");

is_deeply(\%DATA1,\%DATA3,"on post file reload");

is_deeply({},\%DATA2,"on cache reload was not called");

our $pid = fork();
if($pid == 0) {
    $config->setval("section1","param2","newval");
    $config->RewriteConfig;
    exit;
} elsif ( $pid == -1 ){
    die;
}
waitpid ($pid,0);

$config->ReadConfig();

ok("newval" eq $DATA1{"section1"}{"param2"},"on reload was called");

ok(refaddr($config) eq refaddr($config->cache->get($config->GetFileName)),"same refaddr after on reload");

is_deeply(\%DATA1,\%DATA2,"on cache reload was called");

is_deeply(\%DATA1,\%DATA3,"on post file reload");

my $old_value = $config->val("section1","param1");

$config->setval("section1","param1","newval");

$config->Rollback;

ok(refaddr($config) eq refaddr($config->cache->get($config->GetFileName)),"same refaddr after Rollback");

ok($config->val("section1","param1") eq  $old_value ,"Rollback");

is_deeply(\%DATA1,\%DATA2,"on cache reload after rollback");

is_deeply(\%DATA1,\%DATA3,"on post file reload after rollback");

$pid = fork();
if($pid == 0) {
    $config->setval("section1","param1","newval");
    $config->RewriteConfig;
    exit;
} elsif ( $pid == -1 ){
    die;
}
waitpid ($pid,0);

dies_ok(sub {$config->RewriteConfig},"Die on writing when timestamp differs");

END {
    if($pid) {
        unlink($filename);
        remove_tree('/tmp/chi');
    }
};

=head1 AUTHOR

Inverse inc. <info@inverse.ca>

=head1 COPYRIGHT

Copyright (C) 2005-2015 Inverse inc.

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


