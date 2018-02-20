#!/usr/bin/perl

use strict;
use warnings;

use File::Find;
use File::Slurp qw(read_file write_file);
use Data::Dumper;
use YAML::XS;

sub dir_yaml_files {
    my ($dir) = @_;
    my @files;
    find({ wanted => sub { push @files, $_ if $_ =~ /\.yaml$/ }, follow => 1, no_chdir => 1}, $dir);
    return sort @files;
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

sub common_parameter {
    my ($yaml_spec, $parameter) = @_;
    for my $path (keys(%{$yaml_spec->{paths}})) {
        for my $method (keys(%{$yaml_spec->{paths}->{$path}})) {
            unless(defined($yaml_spec->{paths}->{$path}->{$method}->{parameters})) {
                $yaml_spec->{paths}->{$path}->{$method}->{parameters} = [];
            }
            push @{$yaml_spec->{paths}->{$path}->{$method}->{parameters}}, $parameter;
        }
    }
}

sub insert_search_parameters {
    my ($yaml_spec) = @_;
    for my $path (keys(%{$yaml_spec->{paths}})) {
        if($path =~ /\/search$/) {
            for my $method (keys(%{$yaml_spec->{paths}->{$path}})) {
                unless(defined($yaml_spec->{paths}->{$path}->{$method}->{parameters})) {
                    $yaml_spec->{paths}->{$path}->{$method}->{parameters} = [];
                }
                push @{$yaml_spec->{paths}->{$path}->{$method}->{parameters}}, {'$ref' => "#/components/parameters/cursor"};
                push @{$yaml_spec->{paths}->{$path}->{$method}->{parameters}}, {'$ref' => "#/components/parameters/limit"};
                push @{$yaml_spec->{paths}->{$path}->{$method}->{parameters}}, {'$ref' => "#/components/parameters/search_query"};
                push @{$yaml_spec->{paths}->{$path}->{$method}->{parameters}}, {'$ref' => "#/components/parameters/fields"};
                push @{$yaml_spec->{paths}->{$path}->{$method}->{parameters}}, {'$ref' => "#/components/parameters/sort"};
            }
        }
    }
}

my $spec = read_file("openapi-base.yaml");

$spec .= <<EOT;

paths:

EOT

my @objects = dir_yaml_files("paths/");

foreach my $object (@objects) {
    $spec = append_to_spec($spec, $object, 1)
}

$spec = join("\n", map { $_ !~ /^\s*$/ ? $_ : () } split("\n", $spec));

$spec .= <<EOT;

components:

EOT

for my $type (("schemas", "responses", "securitySchemes", "parameters")) {

    my @objects = dir_yaml_files("components/$type/");

    $spec .= <<EOT;

  $type:

EOT

    foreach my $object (@objects) {
        $spec = append_to_spec($spec, $object, 2)
    }

}

my $yaml_spec ;

eval {
    $yaml_spec = YAML::XS::Load($spec);
};

if($@) {
    print STDERR "Error while decoding YAML: $@ \n";
    exit 1;
}

common_parameter($yaml_spec, {
    'required' => 0,
    'in' => 'header',
    'name' => 'X-PacketFence-Tenant-Id',
    'schema' => {
                  'type' => 'string'
                },
    'description' => 'The tenant ID to use for this request. Can only be used if the API user has access to other tenants. When empty, it will default to use the tenant attached to the token.'
});

insert_search_parameters($yaml_spec);

YAML::XS::DumpFile("openapi.yaml", $yaml_spec);

system("js-yaml openapi.yaml > openapi.json");

