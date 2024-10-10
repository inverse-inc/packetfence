package pf::UnifiedApi::OpenAPI::Generator::DynamicReports;

=head1 NAME

pf::UnifiedApi::OpenAPI::Generator::DynamicReports -

=head1 DESCRIPTION

pf::UnifiedApi::OpenAPI::Generator::DynamicReports

=cut

use strict;
use warnings;
use lib qw(/usr/local/pf/lib);
use lib qw(/usr/local/pf/lib_perl/lib/perl5);
use Config::IniFiles;
use pf::file_paths qw($report_default_config_file);
use Moo;
$YAML::XS::Boolean = "JSON::PP";
use JSON::MaybeXS ();

extends qw(pf::UnifiedApi::OpenAPI::Generator);

our %OPERATION_GENERATORS = (
    requestBody => {
        (
            map { $_ => "${_}OperationRequestBody" }
              qw(search)
        )
    },
    parameters => {
        (
            map { $_ => "${_}OperationParameters" }
              qw(search list get options)
        )
    },
    description => {
        (
            map { $_ => "operationDescription" }
              qw(search list get options)
        )
    },
    responses => {
        search => {
            400 => {
                "\$ref" => "#/components/responses/BadRequest"
            },
            401 => {
                "\$ref" => "#/components/responses/Forbidden"
            },
            422 => {
                "\$ref" => "#/components/responses/UnprocessableEntity"
            },
        },
        get => {
            200 => {
                "\$ref" => "#/components/responses/Message"
            },
            401 => {
                "\$ref" => "#/components/responses/Forbidden"
            },
        },
        list => {
            200 => {
                "\$ref" => "#/components/responses/Message"
            },
            401 => {
                "\$ref" => "#/components/responses/Forbidden"
            },
        },
        options => {
            200 => {
                "\$ref" => "#/components/responses/DynamicReportMeta"
            },
            401 => {
                "\$ref" => "#/components/responses/Forbidden"
            },
        }
    },
    operationId => {
        (
            map { $_ => "operationId" }
              qw(search list get options)
        )
    },
    tags => {
        (
            map { $_ => "operationTags" }
              qw(search list get options)
        )
    }
);

sub generateSchemas {
    {
        '/components/schemas/DynamicReportSearchRequest' => {
            properties => {
                query => {
                    "\$ref" => "#/components/schemas/Query"
                },
                start_date => {
                    type => 'string',
                    format => 'date-time',
                    example => '1970-01-01 00:00:00',
                },
                end_date => {
                    type => 'string',
                    format => 'date-time',
                    example => '1970-01-01 00:00:00',
                },
                cursor => {
                    oneOf => [
                        { type => 'string' },
                        { type => 'array', items => { type => 'string' } },
                    ],
                },
                limit => {
                    type => 'integer',
                },
            },
            type => 'object',
            additionalProperties => JSON::MaybeXS::true,
        },
    }
}

sub operation_generators {
    \%OPERATION_GENERATORS;
}

my %OPERATION_DESCRIPTIONS = (
    list    => 'List reports',
    search => 'Search a report',
    get     => 'Get a report',
    options => 'Get meta of a report'
);

=head2 operationRequestBody

operationRequestBody

=cut

sub searchOperationRequestBody {
    return {
        content => {
            "application/json" => {
                schema => {
                    '$ref' => '#/components/schemas/DynamicReportSearchRequest'
                }
            }
        },
    }
}

=head2 operationParameters

operationParameters

=cut

sub resourceParameters {
    my ( $self, $scope, $c, $m, $a ) = @_;
    my $parameters = $self->operationParameters( $scope, $c, $m, $a );
    my $parameter = $self->path_parameter('report_id');
    my $ini = Config::IniFiles->new(
        -file => $report_default_config_file,
    );
    my $enum = [];
    for my $section ($ini->Sections) {
        push @$enum, $section;
    };
    $parameter->{schema}->{enum} = \@$enum;
    push @$parameters, $parameter;
    return $parameters;
}

sub searchOperationParameters {
    my ( $self, $scope, $c, $m, $a ) = @_;
    return $self->resourceParameters( $scope, $c, $m, $a );
}

sub getOperationParameters {
    my ( $self, $scope, $c, $m, $a ) = @_;
    return $self->resourceParameters( $scope, $c, $m, $a );
}

sub optionsOperationParameters {
    my ( $self, $scope, $c, $m, $a ) = @_;
    return $self->resourceParameters( $scope, $c, $m, $a );
}

sub listOperationParameters {
    my ( $self, $scope, $c, $m, $a ) = @_;
    return $self->operationParameters( $scope, $c, $m, $a );
}

sub operationDescriptionsLookup {
    return \%OPERATION_DESCRIPTIONS;
}

=head1 AUTHOR

Inverse inc. <info@inverse.ca>

=head1 COPYRIGHT

Copyright (C) 2005-2024 Inverse inc.

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
