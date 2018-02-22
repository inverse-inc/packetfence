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
use pf::UnifiedApi::GenerateSpec;
use boolean;
use pf::file_paths qw($install_dir);
use YAML::XS qw(DumpFile);;

our %METHODS_WITH_ID = (
    get => 1,
    post => 1,
);

our %PATH_CONFIG_HANDLER = (
    collection => {
        'post'   => \&configCollectionPost,
        'get'    => \&configCollectionGet,
    },
    resource => {
        'get'    => \&configResourceGet,
        'put'    => \&configResourceGet,
        'patch'  => \&configResourceGet,
        'delete' => \&configResourceDelete,
    }
);

my $app = pf::UnifiedApi->new;

my @route_infos = map { walkRootRoutes($_) } @{ $app->routes->children };

my %paths;
for my $route_info (@route_infos) {
   for my $child (@{$route_info->{children}}) {
        my $methods = $child->{methods};
        next if !defined $methods || @$methods == 0;

        my $path = $child->{path};
        next if $path !~ m#/config/#;

        my $controller = "pf::UnifiedApi::Controller::$child->{controller}";
        load $controller;
        my $c = $controller->new(app => $app);

        for my $m (@$methods) {
            $m = lc($m);
            my $form = buildForm($c, $child, $m);
            next if !defined $form;
            $paths{$path}{$m} = pathMethodInfo($m, $child, $form);
        }
   } 
}

{
    my $base_path = "$install_dir/docs/api/spec/paths";
    while (my ($p, $d) = each %paths) {
        my $file_path = $p;
        $file_path =~ s#/\{[^\}]+\}##;
        $file_path = "${base_path}${file_path}.yaml";
        unlink ($file_path);
        local $YAML::UseHeader = 0;
        DumpFile($file_path, {$p => $d});
    }
}

#print Dumper(\%paths, \@route_infos);

sub buildForm {
    my ($c, $child, $m) = @_;
    return undef if $c->can("form_class_by_type");

    my $form_class = $c->form_class;
    return undef if $form_class eq 'pfappserver::Form::Config::Pf';
    
    my $form = $form_class->new( (!exists $METHODS_WITH_ID{$m}) ? (inactive => ['id'] ) : ());
}

sub pathMethodInfo {
    my ($method, $child, $form) = @_;
    my $path_type = $child->{path_type};
    if (exists $PATH_CONFIG_HANDLER{$path_type}{$method}) {
        return $PATH_CONFIG_HANDLER{$path_type}{$method}->($child, $method, $form);
    }
    
    return { }
}

sub standardParameters {
    {
        "description" =>
"The tenant ID to use for this request. Can only be used if the API user has access to other tenants. When empty, it will default to use the tenant attached to the token.",
        "in"       => "header",
        "name"     => "X-PacketFence-Tenant-Id",
        "required" => 0,
        "schema"   => {
            "type" => "string"
        }
    }

}

sub configCollectionPostJsonSchema {
    my ($method, $child, $form) = @_;
    return "schema" => pf::UnifiedApi::GenerateSpec::objectSchema($form)
}

sub configResourcePut {
    my ($method, $child, $form) = @_;
    {
        "parameters" => [
            standardParameters()
        ],
        "requestBody" => {
            "content" => {
                "application/json" => {
                    configCollectionPostJsonSchema($method, $child, $form)
                }
            },
            "required" => true,
        },
        "responses" => {
            "201" => {
                "\$ref" => "#/components/responses/Created"
            },
            "400" => {
                "\$ref" => "#/components/responses/BadRequest"
            },
            "422" => {
                "\$ref" => "#/components/responses/UnprocessableEntity"
            }
        },
    };
}

sub configResourceGet {
    my ($method, $child, $form) = @_;
    {
        "parameters" => [
            standardParameters()
        ],
        "requestBody" => {
            "content" => {
                "application/json" => {
                    configCollectionPostJsonSchema($method, $child, $form)
                }
            },
            "required" => true,
        },
        "responses" => {
            "201" => {
                "\$ref" => "#/components/responses/Created"
            },
            "400" => {
                "\$ref" => "#/components/responses/BadRequest"
            },
            "422" => {
                "\$ref" => "#/components/responses/UnprocessableEntity"
            }
        },
    };
}

sub configCollectionPost {
    my ($method, $child, $form) = @_;
    {
        "parameters" => [
            standardParameters()
        ],
        "requestBody" => {
            "content" => {
                "application/json" => {
                    configCollectionPostJsonSchema($method, $child, $form)
                }
            },
            "required" => true,
        },
        "responses" => {
            "201" => {
                "\$ref" => "#/components/responses/Created"
            },
            "400" => {
                "\$ref" => "#/components/responses/BadRequest"
            },
            "409" => {
                "\$ref" => "#/components/responses/Duplicate"
            },
            "422" => {
                "\$ref" => "#/components/responses/UnprocessableEntity"
            }
        },
    };
}

sub configCollectionGet {
    my ( $method, $child, $form ) = @_;
    {
        "parameters" => [
            standardParameters(),
            { "\$ref" => '#/components/parameters/cursor' }
        ],
        "responses" => {
            "400" => {
                "\$ref" => "#/components/responses/BadRequest"
            },
            "422" => {
                "\$ref" => "#/components/responses/UnprocessableEntity"
            },
            '200' => {
                "description" => "A list of connection profiles",
                "content"     => {
                    "application/json" => {
                        "schema" => {
                            "allOf" => [
                                {
                                    "\$ref" => "#/components/schemas/Iterable",
                                },
                                {
                                    'type' => 'object',
                                    'properties' => {
                                        items => pf::UnifiedApi::GenerateSpec::objectSchema( $form),
                                    }
                                }
                            ]
                        }
                    }
                }
            }
        },
    };
}

sub configResourceDelete {
    {
        summary     => 'Delete a config item',
        "parameters" => [
            standardParameters()
        ],
        'responses' => {
            '204' => {
                description => 'Deleted a config item'
            }
        }
    }
}

sub baseInfo {
    my ($path_part) = @_;
    return {
        servers => [ { url => "http://localhost:9999$path_part" } ],
        info    => {
            description =>
'An API to access the PacketFence resources. Lets make the PacketFence API great again!',
            title   => 'PacketFence API',
            version => '0.0.1',
            openapi => '3.0.0',
        },
        security => [ { bearerAuth => [] }, ]
    };
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

    if ( $depth == 0 ) {
        $info{base} = baseInfo($path_part);
        #@paths = ( @$parent_paths, $path_part );
    }
    else {
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

