#!/usr/bin/perl

=head1 NAME

mk-pfmon-task - 

=cut

=head1 DESCRIPTION

mk-pfmon-task

=cut

use strict;
use warnings;
use lib qw(/usr/local/pf/lib);
use Template;
use pf::config qw(%Config %Default_Config %Doc_Config);
use Data::Dumper;
use pf::file_paths qw($install_dir);
use pf::util qw(normalize_time);

my $tt = Template->new(
    OUTPUT_PATH => $install_dir,
    INCLUDE_PATH => "$install_dir/addons/dev-helpers/templates/",
);

my @keys = keys %{$Config{maintenance}};

my @tasks = map { /^(.*)_interval$/;$1} grep { /^(.*)_interval$/ } @keys;

my @config_info;

my %field_types = (
    window => 'Duration',
    timeout => 'Duration',
    batch => 'PosInteger'
);

foreach my $task (sort @tasks) {
    my @attributes;
    my $class = $task;
    my %vars  = (
        class => $class,
        name => $class,
        attributes => \@attributes,
        enabled  => 'enabled',
    );
    if (exists $Default_Config{maintenance}{$task} ) {
       $vars{enabled} = $Default_Config{maintenance}{$task};
    }
    for my $attrib_name (sort grep { /^${task}_/ } @keys) {
        my $value = $Default_Config{maintenance}{$attrib_name};
        if ($attrib_name =~ /_interval$/) {
            $vars{interval} = $value;
            my $interval = normalize_time($value);
            if ($interval == 0 ) {
               $vars{enabled} = 'disabled';
            }
            next;
        }
        my $default = $value;
        my $type = $Doc_Config{"maintenance.$attrib_name"}{type};
        if ($type eq 'time') {
            $default = normalize_time($default);
        } elsif ($type ne 'numeric') {
            $default = "\"$default\"";
        }
        my $name = $attrib_name;
        $name =~ s/^${task}_//;
        if ($name =~ /window/) {
            $vars{HAS_WINDOW} = 1;
            $vars{enabled} = 'disabled' if $default == 0;
        }
        push @attributes, {name => $name, default => $default, value => $value, comment => mk_comment($class, $name), field_type => mk_field_type($class, $name) };
    }

    my $out_path = "lib/pf/pfmon/task/${class}.pm";

    push @config_info,\%vars;

    if (-e "$install_dir/$out_path") {
        print "Module already exists skipping $out_path\n";
    } else {
        $tt->process("pf-pfmon-task.pm.tt",\%vars, $out_path) or die $tt->error;
    }

    $out_path = "html/pfappserver/lib/pfappserver/Form/Config/Pfmon/${class}.pm";
    if (-e "$install_dir/$out_path") {
        print "Module already exists skipping $out_path\n";
    } else {
        $tt->process("form-config-pfmon.pm.tt",\%vars, $out_path) or die $tt->error;
    }

    #print Dumper(\%vars);
    
}

sub mk_field_type {
    my ($class, $name) = @_;
    return $field_types{$name} if exists $field_types{$name};
    return 'Text';
}
$tt->process("pfmon.conf.tt",{ 'configs' => \@config_info}, "conf/pfmon.conf.defaults") or die $tt->error;


sub mk_comment {
    my ($class, $name) = @_;
    my $comment = "TODO: comment for $class.$name";
    if ($name =~ /timeout/) {
        $comment = "How long a $class job can run"
    } elsif ($name =~ /batch/) {
        $comment = "How many $class entries to clean up in one run";
    } elsif ($name =~ 'window') {
        $comment = "How long to keep a $class entry before deleting it"
    }
    return $comment;
}


=head1 AUTHOR

Inverse inc. <info@inverse.ca>

=head1 COPYRIGHT

Copyright (C) 2005-2017 Inverse inc.

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

