#!/usr/bin/perl

=head1 NAME

template

=cut

=head1 DESCRIPTION

unit test for template

=cut

use strict;
use warnings;
use Template::Parser;
#
use lib '/usr/local/pf/lib';

BEGIN {
    #include test libs
    use lib qw(/usr/local/pf/t);
}

use File::Find;

use Test::More;

#This test will running last
use Test::NoWarnings;

our @FILES;
our $TESTS;
our $PARSER;

sub setup {
    @FILES = (
        file_templates(qr/^.*\.(tt|inc)\z/s, '/usr/local/pf/html/pfappserver/root'),
        file_templates(qr/^.*\.tt\z/s, '/usr/local/pf/conf', '/usr/local/pf/addons'),
        file_templates(qr/^.*\.tt.example\z/s, '/usr/local/pf/conf'),
        file_templates(qr/^.*\.(html|inc|tt|xml)\z/s, '/usr/local/pf/html/captive-portal/templates'),
    );
    $TESTS = (scalar @FILES) + 1;
    $PARSER = Template::Parser->new;
    plan tests => $TESTS;
}

setup();
runtests();

sub runtests {
    foreach my $file (@FILES) {
        test_template($file)
    }
}

sub test_template {
    my ($file) = @_;
    my $text = slurp_file($file);
    my $template = $PARSER->parse($text);
    ok($template, "Syntax check for template toolkit file '$file'");
}

sub slurp_file {
    my ($file) = @_;
    die "file '$file' does not exists\n" unless -e $file;
    open(my $fh, "<", $file) or die "file '$file' cannot be opened\n";
    local $/ = undef;
    my $content = <$fh>;
    return $content;
}

sub file_templates {
    my ($pattern, @paths) = @_;
    my @list;
    File::Find::find({wanted => sub {
        /$pattern/ && push @list, $File::Find::name;
    }}, @paths);
    return @list;
}

=head1 AUTHOR

Inverse inc. <info@inverse.ca>

=head1 COPYRIGHT

Copyright (C) 2005-2019 Inverse inc.

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

