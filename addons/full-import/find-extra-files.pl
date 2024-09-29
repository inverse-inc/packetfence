#!/usr/bin/perl

use strict;
use warnings;

use lib '/usr/local/pf/lib';
use lib '/usr/local/pf/lib_perl/lib/perl5';

use pf::file_paths;
use Config::IniFiles;

my %ignored = (
    $pf::file_paths::oui_file => 1,
    $pf::file_paths::allowed_device_oui_file => 1,
    $pf::file_paths::allowed_device_types_file => 1,
    $pf::file_paths::oauth_ip_file => 1,
    $pf::file_paths::log_config_file => 1,
);

my %ignored_params = (
    $pf::file_paths::authentication_config_file => {
        authorize_path => 1,
        access_token_path => 1,
    },
    $pf::file_paths::pf_config_file => {
        image_path => 1,
    },
);

my @extra_files_to_export = (
    $pf::file_paths::fingerbank_config_file,
    $pf::file_paths::firewalld_input_config_inc_file,
    $pf::file_paths::firewalld_input_management_config_inc_file,
    $pf::file_paths::firewalld6_input_config_inc_file,
    $pf::file_paths::firewalld6_input_management_config_inc_file,
    $pf::file_paths::report_config_file,
);


for my $file (@pf::file_paths::stored_config_files) {
    next if $ignored{$file};
    next unless -f $file;

    my $local_ignored_params = $ignored_params{$file} // {};

    my $c = Config::IniFiles->new(-file => $file, -allowempty => 1);
    for my $section ($c->Sections) {
        for my $param ($c->Parameters($section)) {
            next if $local_ignored_params->{$param};
            if($param =~ /(_file|_path)$/ || $param eq "file" || $param eq "path") {
                print $c->val($section, $param) . "\n";
            }
            elsif($param eq "logo") {
                my $logo_path = $c->val($section, $param);
                if($logo_path =~ /^\/common\//) {
                    print "/usr/local/pf/html$logo_path\n"
                }
                elsif($logo_path =~ /^\/content\//) {
                    print "/usr/local/pf/html/captive-portal$logo_path\n";
                }
            }
        }
    }
}

for my $file (@extra_files_to_export) {
    next unless -f $file;
    print $file . "\n";
}
