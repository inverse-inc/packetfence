#!/usr/bin/perl

use strict;
use warnings;

use File::Find;
use File::Slurp qw(read_file write_file);
use Data::Dumper;

sub dir_yaml_files {
    my ($dir) = @_;
    my @files;
    find({ wanted => sub { push @files, $_ if $_ =~ /\.yaml$/ }, follow => 1, no_chdir => 1}, $dir);
    return @files;
}

sub indent_content {
    my ($content, $amount_of_spaces) = @_;
    return join("\n", map { " " x $amount_of_spaces .  $_ } split("\n", $content));
}

sub append_to_spec {
    my ($spec, $file, $indent_level) = @_;
    
    my $content = read_file($file);
    # prefix all lines with the indent level times 2 spaces
    my $indented_content = indent_content($content, $indent_level * 2);
    $spec .= "\n# beginning of: $file \n";
    $spec .= "$indented_content\n";
    $spec .= "\n# end of: $file \n";

    return $spec;
}

my $spec = read_file("openapi-base.yaml");

$spec .= <<EOT;

components:

EOT

for my $type (("schemas", "responses", "securitySchemes")) {

    my @objects = dir_yaml_files("components/$type/");

    $spec .= <<EOT;

  $type:

EOT

    foreach my $object (@objects) {
        $spec = append_to_spec($spec, $object, 2)
    }

}

$spec .= <<EOT;

paths:

EOT

my @objects = dir_yaml_files("paths/");

foreach my $object (@objects) {
    $spec = append_to_spec($spec, $object, 1)
}

$spec = join("\n", map { $_ !~ /^\s*$/ ? $_ : () } split("\n", $spec));

print $spec;

write_file("openapi.yaml", $spec);

