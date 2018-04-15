#!/usr/bin/perl

=head1 NAME

generate_openapi_from_routes -

=cut

=head1 DESCRIPTION

generate_openapi_from_routes

=cut

use strict;
use warnings;
use lib qw(/usr/local/pf/lib);
use pf::UnifiedApi;
use re 'regexp_pattern';
use Data::Dumper;
use Module::Load;
use File::Spec;
use pf::UnifiedApi::GenerateSpec;
use boolean;
use pf::file_paths qw($install_dir);
use YAML::XS qw(Dump);;
use File::Slurp qw(write_file);
use File::Path qw(make_path);
$YAML::XS::Boolean = 'boolean';

my $app = pf::UnifiedApi->new;

my %routes;
for my $route_info (map { walkRootRoutes($_) } @{ $app->routes->children }) {
   for my $child (@{$route_info->{children}}) {
        next if !defined $child->{methods};
        push @{$routes{paths}{$child->{path}}}, $child;
        push @{$routes{controllers}{$child->{controller}}}, $child;
   } 
}

my $openapi_paths = generateOpenAPIPaths($app, $routes{paths} // {});
saveToYaml($openapi_paths, "$install_dir/docs/api/spec/paths");
my $openapi_schemas = generateOpenAPISchemas($app, $routes{controllers});
saveToYaml($openapi_schemas, "$install_dir/docs/api/spec");

sub saveToYaml {
    my ($yamls, $base_path) = @_;
    while (my ($p, $d) = each %$yamls) {
        next if !defined $d;
        my $file_path = $p;
        $file_path =~ s#/\{[^\}]+\}##;
        $file_path = "${base_path}${file_path}.yaml";
        unlink ($file_path);
        my $dump = Dump({$p => $d});
        $dump =~ s/---\n//;
        my (undef, $dir, undef ) = File::Spec->splitpath( $file_path );
        make_path($dir);
        write_file($file_path, $dump);
    }
}

#print Dumper(\%paths, \@route_infos);
sub generateOpenAPIPaths {
    my ($app, $paths) = @_;
    my %openapi_paths;
    while ( my ( $path, $actions ) = each %$paths ) {
        my $sub_class        = $actions->[0]->{controller};
        my $controller_class = "pf::UnifiedApi::Controller::${sub_class}";
        load $controller_class;
        my $controller = $controller_class->new(app => $app);
        my $generator = $controller->openapi_generator;
        next if !defined $generator;
        my $data = $generator->generate_path($controller, $actions);
        next if !defined $data;
        $openapi_paths{$path} = $data;
    }
    return \%openapi_paths;
}

sub generateOpenAPISchemas {
    my ($app, $sub_classes) = @_;
    my %openapi_schemas;
    while (my ($sub_class, $actions) = each %$sub_classes) {
        my $controller_class = "pf::UnifiedApi::Controller::${sub_class}";
        load $controller_class;
        my $controller = $controller_class->new(app => $app);
        my $generator = $controller->openapi_generator;
        my $schemas = $generator->generate_schemas($controller, $actions);
        if ($schemas) {
            %openapi_schemas = (%openapi_schemas, %$schemas);
        }
    }
    return \%openapi_schemas;
}

sub walkRootRoutes {
    my ($route) = @_;
    my ($root, @children) = walk( $route, 0, '', [] );
    if (!defined $root) {
        return;
    }
    $root->{children} = \@children;
    return $root;
}

sub walk {
    my ( $route, $depth, $parent, $parent_paths ) = @_;
    my $children = $route->children;
    if ( $depth == 0 && @$children == 0 ) {
        return;
    }

    my $verbose   = 1;
    my $rows      = [];
    my $path_part = $route->pattern->unparsed || '';
    $path_part =~ s#/:([^/]+)#/\{$1\}#;
    my @paths;    #     = ( @$parent_paths, $path_part );
    my $full_path = "${parent}$path_part";
    my $path_type = $full_path =~ /\}$/ ? 'resource' : 'collection';
    my %info      = (
        full_path => $full_path,
        children  => [],
        path_part => $path_part,
        paths     => \@paths,
        depth     => $depth,
        path_type => $path_type, 
    );

    if ( $depth ) {
        if ($path_part) {
            @paths = ( @$parent_paths, $path_part );
        }
        else {
            @paths = @$parent_paths;
        }
    }

     $info{path} = join('', @paths);

    # Pattern
    my $prefix = '';
    if ( my $i = $depth * 2 ) { $prefix .= ' ' x $i . '+' }
    push @$rows, my $row = [ $prefix . ( $route->pattern->unparsed || '/' ) ];
    my $to = $route->to;

    # Flags
    my @flags;
    push @flags, @{ $route->over || [] } ? 'C' : '.';
    push @flags, ( my $partial = $route->partial ) ? 'D' : '.';
    push @flags, $route->inline       ? 'U' : '.';
    push @flags, $route->is_websocket ? 'W' : '.';
    push @$row, join( '', @flags ) if $verbose;

    # Methods
    my $via = $route->via;
    push @$row, !$via ? '*' : uc join ',', @$via;
    $info{methods} = $via;
    $info{operationId} = $info{name} = $route->name;

    # Name
    my $name = $route->name;
    push @$row, $route->has_custom_name ? qq{"$name"} : $name;

    # Regex (verbose)
    my $pattern = $route->pattern;
    $pattern->match( '/', $route->is_endpoint && !$partial );
    push @$row, ( regexp_pattern $pattern->regex )[0] if $verbose;

    push @$row,
      defined $to->{controller} ? "$to->{controller}#$to->{action}" : ''
      if $verbose;
    if ( defined $to->{controller} ) {
        $info{controller} = $to->{controller};
        $info{action}     = $to->{action};
    }

    $depth++;
    my @children = map { walk( $_, $depth, $full_path, \@paths ) } @$children;
    return \%info, @children;
}

=head1 AUTHOR

Inverse inc. <info@inverse.ca>

=head1 COPYRIGHT

Copyright (C) 2005-2018 Inverse inc.

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

