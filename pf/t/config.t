#!/usr/bin/perl -w

use strict;
use warnings;
use diagnostics;

use Test::More;
use Config::IniFiles;

my %default_cfg;
my %doc;

tie %default_cfg, 'Config::IniFiles',
    ( -file => "/usr/local/pf/conf/pf.conf.defaults" );
tie %doc, 'Config::IniFiles',
    ( -file => "/usr/local/pf/conf/documentation.conf" );

#plan the number of tests
my $testNb = 0;
foreach my $section ( tied(%default_cfg)->Sections ) {
    foreach my $key ( keys( %{ $default_cfg{$section} } ) ) {
        if ($section ne 'proxies') {
            $testNb++;
        }
    }
}
foreach my $section ( tied(%doc)->Sections ) {
    if ( ($section ne 'proxies')
        && ($section ne 'passthroughs') 
        ) {
        if ($section =~ /^([^.]+)\.(.+)$/) {
            if (    ($1 ne 'dhcp')
                 && ($1 ne 'scope')
                 && ($1 ne 'interface')
                 && ($1 ne 'services')
                 && (! ( ($1 eq 'alerting') && ($2 eq 'fromaddr') ) )
                 && (! ( ($1 eq 'arp') && ($2 eq 'listendevice') ) )
               ) {
                 $testNb++;
            }
        } else {
            die("unable to parse section $section");
        }
    }
}
plan tests => $testNb;

#run the tests
foreach my $section ( tied(%default_cfg)->Sections ) {
    foreach my $key ( keys( %{ $default_cfg{$section} } ) ) {
        if ($section ne 'proxies') {
            my $param = "$section.$key";
            ok ( exists($doc{$param}{'description'}),
                 "$param is documented" );
        }
    }
}

foreach my $section ( tied(%doc)->Sections ) {
    if ( ($section ne 'proxies')
        && ($section ne 'passthroughs')
        ) {
        if ($section =~ /^([^.]+)\.(.+)$/) {
            if (    ($1 ne 'dhcp')
                 && ($1 ne 'scope')
                 && ($1 ne 'interface')
                 && ($1 ne 'services')
                 && (! ( ($1 eq 'alerting') && ($2 eq 'fromaddr') ) )
                 && (! ( ($1 eq 'arp') && ($2 eq 'listendevice') ) )
               ) {
                ok ( exists($default_cfg{$1}{$2}),
                     "$section has default value" );
            }
        } else {
            die("unable to parse section $section");
        }
    }
}

# TODO add tests for configfile import / export
