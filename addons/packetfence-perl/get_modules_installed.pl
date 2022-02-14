#!/usr/bin/perl -w
use ExtUtils::Installed;
my $inst    = ExtUtils::Installed->new();
my @modules = $inst->modules();
foreach $module (@modules){
    print "$module," . $inst->version($module) . "\n";
}
