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
use Getopt::Long;
$YAML::XS::Boolean = "JSON::PP";
my $base_path = "$install_dir/docs/api/spec";

# The admin UI extensions (html/pfappserver/root/extensions/README.md) can
# provide static paths and components in <extension>/docs/api/spec/static. They
# are private, so they are only merged on demand: openapi.json and openapi.yaml
# are committed in the public repository.
my $with_extensions = $ENV{PF_API_SPEC_EXTENSIONS} ? 1 : 0;
GetOptions('with-extensions!' => \$with_extensions)
    or die "usage: $0 [--with-extensions]\n";

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

merge_extensions($spec) if $with_extensions;

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

# a directory relative to $base_path, or an absolute one
sub full_dir {
    my ($dir) = @_;
    return $dir =~ m#^/# ? $dir : "$base_path/$dir";
}

sub dir_yaml_files {
    my ($dir) = @_;
    my @files;
    find({ wanted => sub { push @files, $_ if $_ =~ /\.yaml$/ }, follow => 1, no_chdir => 1}, full_dir($dir));
    return sort @files;
}

=head2 ui_extensions

The admin UI extensions, found like the UI build does: the drop-ins of
html/pfappserver/root/extensions/ sorted by name (skipping the names starting
with . or _), then the absolute paths of PF_UI_EXTENSIONS (':' separated).

=cut

sub ui_extensions {
    my @extensions;
    my $dropin = "$install_dir/html/pfappserver/root/extensions";
    if (opendir(my $dh, $dropin)) {
        for my $name (sort grep { !/^[._]/ && -d "$dropin/$_" } readdir($dh)) {
            push @extensions, [$name, "$dropin/$name"];
        }
        closedir($dh);
    }
    for my $dir (grep { length } split(/:/, $ENV{PF_UI_EXTENSIONS} // '')) {
        die "PF_UI_EXTENSIONS entry $dir must be an absolute path to a directory\n" if $dir !~ m#^/# || !-d $dir;
        $dir =~ s#/+$##;
        my ($name) = $dir =~ m#([^/]+)$#;
        push @extensions, [$name, $dir];
    }
    return @extensions;
}

=head2 merge_extensions

Merge the static paths and components of the admin UI extensions, after the
core ones: an extension replaces a core path or component with the same name.

=cut

sub merge_extensions {
    my ($spec) = @_;
    my @merged;
    for my $extension (ui_extensions()) {
        my ($id, $dir) = @$extension;
        my $static = "$dir/docs/api/spec/static";
        next unless -d $static;
        push @merged, $id;
        if (-d "$static/paths") {
            my %paths;
            merge_yaml_into_paths(\%paths, "$static/paths");
            for my $path (sort keys %paths) {
                warn "WARNING: extension '$id' replaces the path '$path'\n" if exists $spec->{paths}{$path};
                $paths{$path}{'x-pf-extension'} = $id;
                $spec->{paths}{$path} = $paths{$path};
            }
        }
        if (-d "$static/components") {
            my $components = hash_yaml_dir("$static/components");
            for my $type (sort keys %$components) {
                for my $name (sort keys %{$components->{$type}}) {
                    warn "WARNING: extension '$id' replaces the component '$type/$name'\n" if exists $spec->{components}{$type}{$name};
                }
            }
            # Hash::Merge is left precedent: the extension wins
            $spec->{components} = merge($components, $spec->{components});
        }
    }
    if (@merged) {
        warn "Merged the API specifications of the UI extensions: " . join(', ', @merged) . "\n"
           . "Do not commit openapi.json and openapi.yaml, restore them with git-unstage-generated.sh\n";
    }
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
    my $full_path = full_dir($dir);
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

