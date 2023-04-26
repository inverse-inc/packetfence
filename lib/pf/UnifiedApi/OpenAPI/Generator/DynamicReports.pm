package pf::UnifiedApi::OpenAPI::Generator::DynamicReports;

=head1 NAME

pf::UnifiedApi::OpenAPI::Generator::DynamicReports -

=head1 DESCRIPTION

pf::UnifiedApi::OpenAPI::Generator::DynamicReports

=cut

use strict;
use warnings;
use Moo;
$YAML::XS::Boolean = "JSON::PP";
use JSON::MaybeXS ();

extends qw(pf::UnifiedApi::OpenAPI::Generator);
our %OPERATION_GENERATORS = (
    requestBody => {
        search => {
            content => {
                "application/json" => {
                    schema => {
                        '$ref' => '#/components/schemas/ReportSearchRequest'
                    }
                }
            },
        },
        get => {
            content => {
                "application/json" => {
                    schema => {
                        '$ref' => '#/components/schemas/ReportSearchRequest'
                    }
                }
            },
        },
        list => {
            content => {
                "application/json" => {
                    schema => {
                        '$ref' => '#/components/schemas/ReportSearchRequest'
                    }
                }
            },
        },

    },
    parameters => {
        (
            map { $_ => "${_}OperationParameters" }
              qw(create search list get replace update remove)
        )
    },
    responses => {
        search => {
            "400" => {
                "\$ref" => "#/components/responses/BadRequest"
            },
            "422" => {
                "\$ref" => "#/components/responses/UnprocessableEntity"
            },
        },
        get => {
            200 => {
                '$ref'=> '#/components/responses/Blah',
            },
        },
        list => {
            200 => {
                '$ref'=> '#/components/responses/Blah',
            },
        }
    },
    tags => {
        (
            map { $_ => "operationTags" }
              qw(create search list get replace update remove)
        )
    },
);

sub generateSchemas {
    {
        '/components/schemas/ReportSearchRequest' => {
            properties => {
                start_date => {
                    type => 'string',
                },
                end_date => {
                    type => 'string',
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

=head2 operationParameters

operationParameters

=cut

sub searchOperationParameters {
    my ( $self, $scope, $c, $m, $a ) = @_;
    return $self->operationParameters( $scope, $c, $m, $a );
}

sub getOperationParameters {
    my ( $self, $scope, $c, $m, $a ) = @_;
    return $self->operationParameters( $scope, $c, $m, $a );
}

sub listOperationParameters {
    my ( $self, $scope, $c, $m, $a ) = @_;
    return $self->operationParameters( $scope, $c, $m, $a );
}


=head2 operationParametersLookup

operation Parameters Lookup

=cut

sub operationParametersLookup {
    return {
        search => "ABC"
    }
}

=head1 AUTHOR

Inverse inc. <info@inverse.ca>

=head1 COPYRIGHT

Copyright (C) 2005-2023 Inverse inc.

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
