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
use pf::util qw(normalize_time);

our $output = "/usr/local/pf/lib/pf/pfmon/task/";
my $tt = Template->new(
    OUTPUT_PATH => $output,
    INCLUDE_PATH => '/usr/local/pf/addons/dev-helpers/templates/',
);

my @keys = keys %{$Config{maintenance}};

my @tasks = map { /^(.*)_interval$/;$1} grep { /^(.*)_interval$/ } @keys;

foreach my $task (@tasks) {
    my @attributes;
    my $class = $task;
    my %vars  = (
        class => $class,
        attributes => \@attributes
    );
    for my $attrib_name (grep { /^${task}_/ } @keys) {
        next if $attrib_name =~ /_interval$/;
        my $name = $attrib_name;
        my $default = $Default_Config{maintenance}{$attrib_name};
        my $type = $Doc_Config{"maintenance.$attrib_name"}{type};
        if ($type eq 'time') {
            $default = normalize_time($default);
        } elsif ($type ne 'numeric') {
            $default = "\"$default\"";
        }
        $name =~ s/^${task}_//;
        if ($name eq 'window') {
            $vars{HAS_WINDOW} = 1;
        }
        push @attributes, {name => $name, default => $default};
    }

    if (-e "$output/${class}.pm") {
        print "Module already exists skipping pf::pfmon::task::${class}\n";
    }
    $tt->process("pf-pfmon-task.pm.tt",\%vars, "${class}.pm") or die $tt->error;

    #print Dumper(\%vars);
    
}

=head1 AUTHOR

Inverse inc. <info@inverse.ca>

=head1 COPYRIGHT

Copyright (C) 2005-2016 Inverse inc.

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

