package pf::survey;
=head1 NAME

pf::survey - storing suvery data

=cut

=head1 DESCRIPTION

pf::survey

=cut

use strict;
use warnings;

use constant SURVEY => 'survey';

BEGIN {
    use Exporter ();
    our ( @ISA, @EXPORT );
    @ISA = qw(Exporter);
    @EXPORT = qw(
        survey_db_prepare
        $survey_db_prepared
        survey_add
    );
}

use pf::config;
use pf::util;
use pf::db;

# The next two variables and the _prepare sub are required for database handling magic (see pf::db)
our $survey_db_prepared = 0;
# in this hash reference we hold the database statements. We pass it to the query handler and he will repopulate
# the hash if required
our $survey_statements = {};

our @SURVEY_FIELDS = ( qw(survey_value email age gender origin source_id) );

sub survey_db_prepare {
    my $logger = Log::Log4perl::get_logger('pf::survey');
    $logger->debug("Preparing pf::survey database queries");

    $survey_statements->{'survey_add_sql'} = get_db_handle()->prepare(
        qq[ insert into survey(survey_value,email,age,gender,origin) values(?,?,?,?,?) ]);

    $survey_db_prepared = 1;
}

sub survey_add {
    my (%survey) = @_;
    db_query_execute(SURVEY, $survey_statements, 'survey_add_sql',@survey{@SURVEY_FIELDS})
        || return (0);
    return (1);
}

sub survey_save_request_into_session {
    my ($session, $request) = @_;
    foreach my $field (qw(survey_value)) {
        my $value = $request->param($field);
        if(defined $value) {
            $session->{$field} = $value;
        }
    }
}

sub survey_add_from_session {
    my ($session) = @_;
    if(defined $session->{survey_value}) {
        my %data;
        @data{@SURVEY_FIELDS} = @{$session}{@SURVEY_FIELDS};
        survery_add_from_oauth_response(\%data, $session->{oauth_response} ) if $session->{oauth_response};
        survey_add(%data);
    }
}

sub survery_add_from_oauth_response {
    my ($data, $oauth_response) = @_;
    $data->{email} = $oauth_response->{email} if $oauth_response->{email};
    $data->{gender} = $oauth_response->{gender} if $oauth_response->{gender};
    $data->{age} = $oauth_response->{birthday} if $oauth_response->{birthday};
    $data->{origin} = $oauth_response->{locale} if $oauth_response->{locale};
}

=head1 AUTHOR

Inverse inc. <info@inverse.ca>

=head1 COPYRIGHT

Copyright (C) 2005-2015 Inverse inc.

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
