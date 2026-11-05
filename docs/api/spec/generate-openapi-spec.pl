#!/usr/bin/perl

use strict;
use warnings;

use lib qw(/usr/local/pf/lib /usr/local/pf/lib_perl/lib/perl5);
use pf::file_paths qw($install_dir);
use pf::services;
use File::Find;
use File::Slurp qw(read_file write_file);
use Data::Dumper;
use JSON::MaybeXS qw();
use YAML::XS qw(:all);
use JSON::PP qw();
use Hash::Merge qw(merge);
$YAML::XS::Boolean = "JSON::PP";
my $base_path = "$install_dir/docs/api/spec";

my $spec = LoadFile("$base_path/openapi-base.yaml");

merge_yaml_into_paths($spec->{paths}, "paths");
merge_yaml_into_paths($spec->{paths}, "deprecated/paths");
merge_yaml_into_paths($spec->{paths}, "static/paths");

my $components = hash_yaml_dir("components");
my $components_deprecated = hash_yaml_dir("deprecated/components");
my $components_static = hash_yaml_dir("static/components");

# Check for duplicate schema names before merging
my %all_schemas;
for my $comp_set ($components, $components_deprecated, $components_static) {
    if (exists $comp_set->{schemas}) {
        for my $name (keys %{$comp_set->{schemas}}) {
            if (exists $all_schemas{$name}) {
                warn "WARNING: Duplicate schema '$name' found in multiple component sets\n";
            }
            $all_schemas{$name} = 1;
        }
    }
}

$spec->{components} = merge($components, merge($components_deprecated, $components_static));

insert_search_parameters($spec);
fix_discriminator_mappings($spec);
add_go_names_for_duplicates($spec);

# insert service paramters
$spec->{components}->{parameters}->{service} = {
  name => 'service',
  in => 'path',
  required =>  JSON::MaybeXS::true,
  description => 'Service unique identifier.',
  schema => {
    type => 'string',
    enum => [ map {$_->name} grep { $_->name ne 'pf' } @pf::services::ALL_MANAGERS ],
  },
};

YAML::XS::DumpFile("$base_path/openapi.yaml", $spec);

write_file("$base_path/openapi.json", {binmode => ':utf8'}, JSON::MaybeXS->new->pretty(1)->canonical(1)->encode($spec));

sub dir_yaml_files {
    my ($dir) = @_;
    my @files;
    find({ wanted => sub { push @files, $_ if $_ =~ /\.yaml$/ }, follow => 1, no_chdir => 1}, "$base_path/$dir");
    return sort @files;
}

my %HTTP_METHODS = (
    map { $_ => 1 } qw(get post head patch delete options put patch)
);

sub common_parameters {
    my ($yaml_spec, @parameters) = @_;
    for my $path (values %{$yaml_spec->{paths}}) {
        while ( my ($k, $method) = each %$path) {
            next if !exists $HTTP_METHODS{lc($k)};
            push @{$method->{parameters}}, @parameters;
        }
    }
}

sub insert_search_parameters {
    my ($yaml_spec) = @_;
    while ( my ( $name, $path ) = each %{ $yaml_spec->{paths} } ) {
        next if $name !~ m#/search#;
        while ( my ($k, $method) = each %$path) {
            next if !exists $HTTP_METHODS{lc($k)};
            push @{ $method->{parameters} },
              { '$ref' => "#/components/parameters/cursor" },
              { '$ref' => "#/components/parameters/limit" },
              { '$ref' => "#/components/parameters/search_query" },
              { '$ref' => "#/components/parameters/fields" },
              { '$ref' => "#/components/parameters/sort" };
        }
    }
}

sub fix_discriminator_mappings {
    my ($yaml_spec) = @_;
    # Fix schemas with discriminators that have empty mappings
    if (exists $yaml_spec->{components} && exists $yaml_spec->{components}->{schemas}) {
        while (my ($name, $schema) = each %{$yaml_spec->{components}->{schemas}}) {
            if (exists $schema->{discriminator}) {
                my $mapping = $schema->{discriminator}->{mapping};
                # Remove discriminator if mapping is empty or missing
                if (!defined $mapping || ref($mapping) ne 'HASH' || !keys %$mapping) {
                    # Check if all oneOf entries are inline objects (no $ref)
                    my $all_inline = 1;
                    if (exists $schema->{oneOf} && ref($schema->{oneOf}) eq 'ARRAY') {
                        for my $item (@{$schema->{oneOf}}) {
                            if (exists $item->{'$ref'}) {
                                $all_inline = 0;
                                last;
                            }
                        }
                    }
                    # If all are inline objects, remove the discriminator completely
                    if ($all_inline) {
                        delete $schema->{discriminator};
                    }
                }
            }
        }
    }
}

sub add_go_names_for_duplicates {
    my ($yaml_spec) = @_;
    # Add x-go-name for schemas that oapi-codegen thinks are duplicates
    # This is a workaround for oapi-codegen limitations
    
    # Special schema renames (not part of the duplicate pattern)
    my %special_schema_renames = (
        'ConfigCertificateLetsEncrypt' => 'ConfigCertificateLetsEncryptSchema',
        'Service' => 'ServiceSchema',
    );
    
    if (exists $yaml_spec->{components} && exists $yaml_spec->{components}->{schemas}) {
        while (my ($name, $replacement) = each %special_schema_renames) {
            if (exists $yaml_spec->{components}->{schemas}->{$name}) {
                $yaml_spec->{components}->{schemas}->{$name}->{'x-go-name'} = $replacement;
            }
        }
    }
    
    # Automatically handle duplicates across component namespaces
    # Find all names that appear in multiple sections
    my %name_appearances;
    for my $section ('requestBodies', 'responses', 'schemas') {
        if (exists $yaml_spec->{components} && exists $yaml_spec->{components}->{$section}) {
            for my $name (keys %{$yaml_spec->{components}->{$section}}) {
                $name_appearances{$name}{$section} = 1;
            }
        }
    }
    
    # Apply x-go-name to duplicates
    for my $name (keys %name_appearances) {
        my @sections = keys %{$name_appearances{$name}};
        if (@sections > 1) {
            # This name appears in multiple sections, apply x-go-name to disambiguate
            if (exists $name_appearances{$name}{'schemas'}) {
                $yaml_spec->{components}->{schemas}->{$name}->{'x-go-name'} = $name . 'Schema';
            }
            if (exists $name_appearances{$name}{'requestBodies'}) {
                $yaml_spec->{components}->{requestBodies}->{$name}->{'x-go-name'} = $name . 'Request';
            }
            if (exists $name_appearances{$name}{'responses'}) {
                $yaml_spec->{components}->{responses}->{$name}->{'x-go-name'} = $name . 'ResponseDef';
            }
        }
    }
}

sub hash_yaml_dir {
    my ($dir) = @_;
    my %all;
    my $full_path = "$base_path/$dir";
    for my $file (dir_yaml_files($dir)) {
        my $path_parts = $file;
        $path_parts =~ s#\Q$full_path\E/##;
        my @parts = split ('/', $path_parts);
        my $object = LoadFile($file);
        my $root = \%all;
        pop @parts;
        for my $part (@parts) {
            $root = $root->{$part} //= {};
        }
        %$root = (%$root, %$object);
    }
    return \%all;
}


sub merge_yaml_into_paths {
    my ($component, $path) = @_;
    my @files = dir_yaml_files($path);
    for my $file (@files) {
        my $object = eval{ LoadFile($file) };
        if ($@) {
            die "$file : $@\n"
        }
        while (my ($k, $v) = each %$object) {
            $component->{$k} = $v;
        }
    }
}

