#!/usr/bin/perl

=head1 NAME

Report

=head1 DESCRIPTION

unit test for Report

=cut

use strict;
use warnings;

our (@BuildQueryOptionsTests, @NextCursorTests);
our (@CreateBindTests, @IsaTests);
our (@ValidateQueryTests, @ValidateFieldsTests);
our (@ValidateInputTests, @MetaForOptions);
our (%defaultAbstractOptions, @DefaultReports);

BEGIN {
    #include test libs
    use lib qw(/usr/local/pf/t);
    my $true = do { bless \(my $d = 1), "JSON::PP::Boolean" };
    my $false = do { bless \(my $d = 0), "JSON::PP::Boolean" };

    #Module for overriding configuration paths
    use setup_test_config;
    use pf::IniFiles;
    use pf::file_paths qw(
        $report_default_config_file
    );
    use Test2::Tools::Compare qw(array hash item field end match);
    my $defaults = pf::IniFiles->new( -file => $report_default_config_file );
    @DefaultReports = $defaults->Sections();
    %defaultAbstractOptions = (
        offset     => 0,
        limit      => 25,
        sql_limit  => 26,
#        where      => undef,
    );
    @BuildQueryOptionsTests = (
        {
            id  => "User::Registration::Sponsor",
            in  => {},
            out => [
                200,
                {
                    %defaultAbstractOptions,
                    start_date => undef,
                    end_date => undef,
                }
            ],
            check => array {
                item 200;
                item hash {
                };
            },
            msg => 'Default options',
        },
        {
            id => "User::Registration::Sponsor",
            in => {
                limit  => 100,
                cursor => 100,
            },
            out => [
                200,
                {
                    start_date => undef,
                    end_date => undef,
                    %defaultAbstractOptions,
                    offset     => 100,
                    limit      => 100,
                    sql_limit  => 101,
                }
            ],
            msg => 'just limit, cursor',
        },
        {
            id => "User::Registration::Sponsor",
            in => {
                limit      => 100,
                cursor     => 200,
                start_date => '2012-12-25'
            },
            out => [
                200,
                {
                    %defaultAbstractOptions,
                    offset     => 200,
                    limit      => 100,
                    sql_limit  => 101,
                    start_date => '2012-12-25',
                    end_date => undef,
                }
            ],
            msg => 'just start_date limit, cursor',
        },
        {
            id => "User::Registration::SMS",
            in => {
                limit      => 100,
                cursor     => 200,
                start_date => '2012-12-25',
                end_date   => '2013-12-25',
                'sort'     => 'pid',
                query      => {
                    op     => 'and',
                    values => [
                        {
                            op    => 'equals',
                            field => "activation.pid",
                            value => 'bob'
                        },
                    ],
                },
            },
            out => [
                200,
                {
                    %defaultAbstractOptions,
                    offset     => 200,
                    limit      => 100,
                    sql_limit  => 101,
                    order      => 'pid',
                    where      => {
                        'activation.pid' => { '=' => 'bob' }
                    },
                }
            ],
            msg => 'limit, cursor, start_date, end_date, sort, query',
        },
        {
            id  => "Node::Active",
            in  => { cursor => "22:33:22:33:33:33" },
            out => [
                200,
                {
                    cursor    => "22:33:22:33:33:33",
                    limit     => 100,
                    sql_limit => 101
                }
            ],
            msg => 'cursor',
        },
        {
            id  => "Node::Active",
            in  => {},
            out => [
                200,
                {
                    cursor    => "00:00:00:00:00:00",
                    limit     => 100,
                    sql_limit => 101
                }
            ],
            msg => 'empty',
        },
        {
            id => "Node::Report::TestOffset",
            in => {
                limit      => 100,
                cursor     => 200,
            },
            out => [
                200,
                {
                    offset     => 200,
                    limit      => 100,
                    sql_limit  => 101,
                }
            ],
            msg => 'limit, cursor pf::Report::sql cursor_type=offset',
        },
        {
            id => "Authentication::Top Successes::By Connection Profile",
            in => {
                "fields" => [ "profile", "count", "percent" ],
                "limit"  => 100,
                "start_date" => "0000-00-00 00:00:00",
                "end_date"   => "9999-12-31 23:59:59"
            },
            out => [
                200,
                {
                    sql_limit  => 101,
                    limit  => 100,
                    cursor => undef,
                    "start_date" => "0000-00-00 00:00:00",
                    "end_date"   => "9999-12-31 23:59:59",
                }
            ],
            msg => "end_date, end_date",
        }


    );

    @NextCursorTests = (
        {
            id => "Node::Active",
            in => [
                [ {}, {}, { mac => "22:33:22:33:33:33" } ], sql_limit => 3,
            ],
            out     => "22:33:22:33:33:33",
            results => [ {}, {} ],
        },
        {
            id => "Node::Active",
            in => [
                [ {}, {}, { mac => "22:33:22:33:33:33" } ], sql_limit => 4,
            ],
            out => undef,
            results => [ {}, {}, { mac => "22:33:22:33:33:33" } ],

        },
        {
            id => "Node::Report::TestOffset",
            in => [
                [ {}, {}, { mac => "22:33:22:33:33:33" } ],
                sql_limit => 3,
                cursor => 2,
                limit => 2,
            ],
            out     => 4,
            results => [ {}, {} ],
        },
        {
            id => "Node::Report::TestOffset",
            in => [
                [ {}, {}, { mac => "22:33:22:33:33:33" } ],
                sql_limit => 4,
                cursor => 3,
                limit => 3,
            ],
            out => undef,
            results => [ {}, {}, { mac => "22:33:22:33:33:33" } ],

        },
        {
            id => "User::Registration::Sponsor",
            in => [
                [ {}, {}, { mac => "22:33:22:33:33:33" } ],
                limit  => 2,
                cursor => 2,
            ],
            out     => 4,
            results => [ {}, {}, ],
        },
        {
            id => "User::Registration::Sponsor",
            in => [
                [ {}, {}, { mac => "22:33:22:33:33:33" } ],
                limit  => 3,
                cursor => 3,
            ],
            out     => undef,
            results => [ {}, {}, { mac => "22:33:22:33:33:33" } ],
        },
        {
            id => "Node::Report::TestMultiValueCursor",
            in => [
                [ {}, {}, { mac => "22:33:22:33:33:33", detect_date => "1111-11-11 11:11:11" } ],
                sql_limit  => 3,
            ],
            out     => ["1111-11-11 11:11:11", "22:33:22:33:33:33"],
            results => [ {}, {} ],
        },
    );

    @CreateBindTests = (
        {
            id => 'Node::Active',
            in => [
                {
                    cursor    => '00:00:00:00:00:00',
                    sql_limit => 101,
                    limit     => 100,
                }
            ],
            out => [ '00:00:00:00:00:00', 101 ],
        },
        {
            id  => 'Node::Report::Test',
            in  => [ {} ],
            out => [],
        },
        {
            id => 'Node::Report::TestOffset',
            in => [
                {
                    cursor    => 200,
                    sql_limit => 101,
                    limit     => 100,
                }
            ],
            out => [ 101, 200 ],
        },
        {
            id => 'Node::Report::TestDateRange',
            in => [
                {
                    cursor     => 200,
                    sql_limit  => 101,
                    limit      => 100,
                    start_date => '0000-01-01 00:00:00',
                    end_date   => '9999-12-31 23:59:59',
                }
            ],
            out => [ '0000-01-01 00:00:00', '9999-12-31 23:59:59' ],
        },
        {
            id => 'Node::Report::TestMultiValueCursor',
            in => [
                {
                    cursor    => [ 3, '00:00:00:00:00:00' ],
                    sql_limit => 101,
                    limit     => 100,
                    start_date => '0000-01-01 00:00:00',
                    end_date   => '9999-12-31 23:59:59',
                }
            ],
            out => [ '0000-01-01 00:00:00', '9999-12-31 23:59:59', 3, '00:00:00:00:00:00', 101 ],
        }
    );

    @IsaTests = (
        {
            id  => 'User::Registration::Sponsor',
            isa => 'pf::Report::abstract',
        },
        {
            id  => 'Node::Active',
            isa => 'pf::Report::sql',
        }
    );

    @ValidateQueryTests = (
        {
            id => 'User::Registration::Sponsor',
            in => {
                op => 'and',
            },
            out => [],
        },
        {
            id => 'User::Registration::Sponsor',
            in => {
                field => 'garbage',
                op    => 'equals',
                value => '',
            },
            out => [
                {
                    field   => 'garbage',
                    message => 'invalid field',
                }
            ],
        },
        {
            id => 'User::Registration::Sponsor',
            in => {
                field => 'activation.pid',
                op    => 'equals',
                value => 'bob',
            },
            out => [],
        },
        {
            id  => 'User::Registration::Sponsor',
            in  => undef,
            out => [],
        },
        {
            id  => 'User::Registration::Sponsor',
            in  => {
                op => 'and',
                values => [
                    {
                        field => 'garbage',
                        op    => 'equals',
                        value => '',
                    }
                ],
            },
            out => [
                {
                    field   => 'garbage',
                    message => 'invalid field',
                }
            ],
        },
        {
            id  => 'User::Registration::Sponsor',
            in  => {
                op => 'and',
                values => [
                    {
                        field => 'garbage',
                        op    => undef,
                        value => '',
                    }
                ],
            },
            out => [
                { message => 'op (null) is invalid'}
            ],
        },
        {
            id  => 'User::Registration::Sponsor',
            in  => {
                op => 'garbage',
            },
            out => [
                { message => 'op (garbage) is invalid'}
            ],
        },
        {
            id  => 'User::Registration::Sponsor',
            in  => {
                op => 'garbage',
            },
            out => [
                { message => 'op (garbage) is invalid'}
            ],
        },
        {
            id  => 'User::Registration::Sponsor',
            in  => {
                op => 'equals',
                field => undef,
            },
            out => [
                { message => 'field must be set'}
            ],
        },
        {
            id  => 'User::Registration::Sponsor',
            in  => {
                op => 'contains',
                field => 'activation.pid',
            },
            out => [
                { message => 'op (contains) is not allowed to have a null value'}
            ],
        },
    );

#     @ValidateFieldsTests = (
#        {
#            id  => 'User::Registration::Sponsor',
#            in  => ["Garbage"],
#            out => [
#                { message => 'field (Garbage) is invalid' },
#            ],
#            msg => 'Non existing field'
#        },
#        {
#            id  => 'User::Registration::Sponsor',
#            in  => ["MAC Address"],
#            out => [ ],
#            msg => 'Field is valid'
#        },
#    );

    @ValidateInputTests = (
        {
            id => 'User::Registration::Sponsor',
            in  => {
                query => {
                    op => 'equals',
                    field => undef,
                },
            },
            out => [
                422,
                {
                    message => 'invalid request',
                    errors => [
                        {
                            message => "field must be set",
                        }
                    ],
                }
            ],
        },
        {
            id  => 'Node::Report::TestDateRange',
            in  => {
            },
            out => [
                422,
                {
                    message => 'invalid request',
                    errors => [
                        {
                            field => 'start_date',
                            message => "must have a value",
                        },
                        {
                            field => 'end_date',
                            message => "must have a value",
                        }
                    ],
                }
            ],
        },
        {
            id  => 'Node::Report::TestDateRange',
            in  => {
                start_date => '',
                end_date => '',
            },
            out => [
                422,
                {
                    message => 'invalid request',
                    errors => [
                        {
                            field => 'start_date',
                            message => "must have a value",
                        },
                        {
                            field => 'end_date',
                            message => "must have a value",
                        }
                    ],
                }
            ],
        },
   );

    @MetaForOptions = (
        {
            id  => 'Ip4Log::Archive',
            check => hash {
                field id  => 'Ip4Log::Archive';
                field default_start_date => '0000-00-00 00:00:00';
                field default_end_date => match(qr/^\d{4}-\d{2}-\d{2} \d{2}:\d{2}:\d{2}$/);
                field default_limit => 25;
                field date_limit => undef;
                field has_date_range => $true;
                field has_cursor     => $true;
                field has_limit      => $true;
                field description =>
'IP address archive of the devices on your network when enabled (see Maintenance section)';
                field charts => array {
                    item 'scatter@Ip4Log Start Time|Start time';
                    item 'scatter@Ip4Log End Time|End time';
                    end();
                };
                field query_fields => array {
                    item hash {
                        field name => 'ip4log_archive.mac';
                        field text => 'MAC Address';
                        field type => 'string';
                        end();
                    };
                    item hash {
                        field name => 'ip4log_archive.ip';
                        field text => 'IP';
                        field type => 'string';
                        end();
                    };
                    end();
                };
                field columns => array {
                    item hash {
                        field text      => 'MAC Address';
                        field name      => 'MAC Address';
                        field is_person => $false;
                        field is_role   => $false;
                        field is_cursor => $false;
                        field is_node   => $true;
                        end();
                    };
                    item hash {
                        field text      => 'IP';
                        field name      => 'IP';
                        field is_person => $false;
                        field is_role   => $false;
                        field is_cursor => $false;
                        field is_node   => $false;
                        end();
                    };
                    item hash {
                        field text      => 'Start time';
                        field name      => 'Start time';
                        field is_person => $false;
                        field is_role   => $false;
                        field is_cursor => $false;
                        field is_node   => $false;
                        end();
                    };
                    item hash {
                        field text      => 'End time';
                        field name      => 'End time';
                        field is_role   => $false;
                        field is_person => $false;
                        field is_node   => $false;
                        field is_cursor  => $false;
                        end();
                    };
                    end();
                };
                end();
            },
        },
        {
            id  => 'Node::Active',
            out => {
                id  => 'Node::Active',
                default_start_date => undef,
                default_end_date => undef,
                date_limit => undef,
                default_limit => 100,
                query_fields => [],
                columns      => [
                    (
                        map {
                            {
                                text      => $_,
                                name      => $_,
                                is_person => ($_ eq 'pid' ? $true : $false),
                                is_node   => ($_ eq 'mac' ? $true : $false),
                                is_role   => $false,
                                is_cursor   => ($_ eq 'mac' ? $true : $false),
                            }
                        } qw(mac ip start_time pid detect_date regdate status user_agent computername notes last_arp last_dhcp os)
                    )
                ],
                default_start_date => undef,
                default_end_date => undef,
                has_date_range => $false,
                has_cursor     => $true,
                has_limit      => $true,
                description => 'All active nodes',
                charts => ['scatter|regdate'],
            },
        },
        {
            id  => 'Node::Report::Test',
            out => {
                id  => 'Node::Report::Test',
                default_start_date => undef,
                default_end_date => undef,
                date_limit => undef,
                default_limit => 25,
                query_fields => [],
                columns      => [
                    (
                        map {
                            {
                                text      => $_,
                                name      => $_,
                                is_person => $false,
                                is_node   => $false,
                                is_role   => $false,
                                is_cursor  => $false,
                            }
                        } qw(mac ip start_time pid detect_date regdate status user_agent computername notes last_arp last_dhcp os)
                    )
                ],
                has_date_range => $false,
                has_cursor     => $false,
                has_limit      => $false,
                description => 'First node',
                charts => [],
            },
        },
        {
            id  => 'Node::Report::TestDateRange',
            check => hash {
                field id  => 'Node::Report::TestDateRange';
                field default_start_date => '0000-00-00 00:00:00';
                field default_end_date => match(qr/^\d{4}-\d{2}-\d{2} \d{2}:\d{2}:\d{2}$/);
                field default_limit => 25;
                field date_limit => undef;
                field has_date_range => $true;
                field has_cursor     => $false;
                field has_limit      => $false;
                field description => 'First node';
                field charts => array {
                    end();
                };
                field query_fields => array {
                    end();
                };
                field columns => array {
                    for my $c ( qw(mac ip start_time pid detect_date regdate status user_agent computername notes last_arp last_dhcp os)) {
                        item hash {
                            field text      => $c;
                            field name      => $c;
                            field is_person => $false;
                            field is_role   => $false;
                            field is_cursor => $false;
                            field is_node   => $false;
                            end();
                        };
                    };
                    end();
                };
                end();
            },
        },
        {
            id  => 'Node::Report::TestDateLimit',
            check => hash {
                field id  => 'Node::Report::TestDateLimit';
                field default_start_date => match(qr/^\d{4}-\d{2}-\d{2} \d{2}:\d{2}:\d{2}$/);
                field default_end_date => match(qr/^\d{4}-\d{2}-\d{2} \d{2}:\d{2}:\d{2}$/);
                field default_limit => 25;
                field date_limit => '24h';
                field has_date_range => $true;
                field has_cursor     => $false;
                field has_limit      => $false;
                field description => 'First node';
                field charts => array {
                    end();
                };
                field query_fields => array {
                    end();
                };
                field columns => array {
                    for my $c ( qw(mac ip start_time pid detect_date regdate status user_agent computername notes last_arp last_dhcp os)) {
                        item hash {
                            field text      => $c;
                            field name      => $c;
                            field is_person => $false;
                            field is_role   => $false;
                            field is_cursor => $false;
                            field is_node   => $false;
                            end();
                        };
                    };
                    end();
                };
                end();
            },
        }
    );

}

use Test::More tests => 5 + (scalar @BuildQueryOptionsTests) + ( scalar @NextCursorTests ) * 2 + (scalar @CreateBindTests) + (scalar @IsaTests) * 2 + scalar @ValidateQueryTests + scalar @ValidateFieldsTests + scalar @ValidateInputTests + scalar @MetaForOptions + ((scalar @DefaultReports) * 3);

use pf::factory::report;
use pf::error qw(is_success);

#This test will running last
use Test::NoWarnings;

{
    for my $t (@MetaForOptions) {
        my $id     = $t->{id};
        my $report = pf::factory::report->new($id);
        if (!$report) {
            BAIL_OUT("Cannot get report $id");
            next;
        }

        if (defined (my $check = $t->{check})) {
            Test2::Tools::Compare::is(
                $report->meta_for_options(),
                $check,
                "Meta for $id"
            );
            next;
        }

        is_deeply(
            $report->meta_for_options(),
            $t->{out},
            "Meta for $id"
        );
    }
}

{
    for my $t (@ValidateInputTests) {
        my $id     = $t->{id};
        my $report = pf::factory::report->new($id);
        if (!$report) {
            fail("Cannot get report $id");
            next;
        }

        is_deeply(
            [ $report->validate_input($t->{in}) ],
            $t->{out},
            "validate input for $id"
        );
    }
}

{
    for my $t (@IsaTests) {
        my $id = $t->{id};
        my $report = pf::factory::report->new($id);
        if (!$report) {
            fail("Cannot get report $id");
            next;
        }

        ok ($report, "report '$id' created");
        isa_ok ($report, $t->{isa}, );
    }
}

{
    for my $t (@ValidateQueryTests) {
        my $id = $t->{id};
        my $report = pf::factory::report->new($id);
        if (!$report) {
            fail("Cannot get report $id");
            next;
        }

        my $in = $t->{in};
        my @errors;
        $report->validate_query($in, \@errors),
        is_deeply(
            \@errors,
            $t->{out},
            "$id: pf::Report->validate_query"
        );
    }
}

#{
#    for my $t (@ValidateFieldsTests) {
#        my $id = $t->{id};
#        my $report = pf::factory::report->new($id);
#        my $in = $t->{in};
#        my @errors;
#        $report->validate_fields($in, \@errors),
#        is_deeply(
#            \@errors,
#            $t->{out},
#            "$id: pf::Report::sql->validate_fields $t->{msg}"
#        );
#    }
#}

{
    for my $t (@CreateBindTests) {
        my $id = $t->{id};
        my $report = pf::factory::report->new($id);
        if (!$report) {
            fail("Cannot get report $id");
            next;
        }

        my $in = $t->{in};
        is_deeply($report->create_bind(@$in), $t->{out}, "$id: pf::Report::sql->create_bind");
    }
}

{
    for my $t (@BuildQueryOptionsTests) {
        my $id = $t->{id};
        my $report = pf::factory::report->new($id);
        if (!$report) {
            fail("Cannot get report $id");
            next;
        }

        #use Data::Dumper;print Dumper($t->{out});
        is_deeply(
            [$report->build_query_options($t->{in})],
            $t->{out},
            "build_query_options $id with ($t->{msg})",
        );
    }
}

{
    for my $t (@NextCursorTests) {
        my $id = $t->{id};
        my $report = pf::factory::report->new($id);
        my $in = $t->{in};
        if (!$report) {
            fail("Cannot get report $id");
            fail();
            next;
        }

        is_deeply($report->nextCursor(@$in), $t->{out}, "$id: pf::Report->nextCursor");
        is_deeply($in->[0], $t->{results}, "$id: pf::Report::sql->nextCursor results");
    }
}

{
    my $id     = 'Node::Report::TestFormatting';
    my $report = pf::factory::report->new($id);
    if ( !$report ) {
        fail("Cannot get report $id");
    } else {
        is_deeply(
            $report->{formatting},
            [ { field => 'vendor', format => 'oui_to_vendor' } ],
            "Test formatting with ($id)"
        );

        is_deeply(
            $report->format_items(
                [ { mac => "00:11:22:33:44:55", vendor => "00:11:22:33:44:55" } ]
            ),
            [ { mac => "00:11:22:33:44:55", vendor => "CIMSYS Inc" } ]
        );
    }
}

{
    my %defaultInput  = (
        start_date => '2012-12-25',
        end_date   => '2013-12-25',
    );

    for my $id (@DefaultReports) {
        my $report = pf::factory::report->new($id);
        ok(defined $report, "Getting report $id");
        my ($status, $info) = $report->build_query_options({%defaultInput});
        ok(is_success($status), "build_query_options works for $id" );
        ($status, my $data) = $report->query(%$info);
        ok(is_success($status), "query works for $id" );
    }
}

{
    my $id = 'Node::Report::TestMultiValueCursor';
    my $report = pf::factory::report->new($id);
    is_deeply(
        $report->cursor_field,
        [qw(detect_date mac)],
        "Cursor Field is an array"
    );

    is_deeply(
        $report->cursor_default,
        ["0000-01-01 00:00:00", "00:00:00:00:00:00"],
        "Cursor default is an array"
    );
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

