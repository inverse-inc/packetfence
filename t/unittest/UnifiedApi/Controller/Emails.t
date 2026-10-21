#!/usr/bin/perl

=head1 NAME

Emails

=head1 DESCRIPTION

unit test for the language of the emails built by pf::UnifiedApi::Controller::Emails

=cut

use strict;
use warnings;

BEGIN {
    #include test libs
    use lib qw(/usr/local/pf/t);
    #Module for overriding configuration paths
    use setup_test_config;
}

use Test::More tests => 15;
use Test::NoWarnings;
use pf::UnifiedApi::Controller::Emails;

sub locale { pf::UnifiedApi::Controller::Emails::email_locale(@_) }

is(locale('fr'), 'fr_FR', 'language only: first locale of the language');
is(locale('fr-CA'), 'fr_CA', 'language and region');
is(locale('pt_BR'), 'pt_BR', 'locale with an underscore');
is(locale('pt'), 'pt_BR', 'language whose only locale has another region');
is(locale('en'), 'en_US', 'english');
is(locale('de-AT'), 'de_DE', 'unsupported region: first locale of the language');
is(locale('xx'), undef, 'unsupported language');
is(locale('../../etc'), undef, 'invalid value');
is(locale('xx', 'fr'), 'fr_FR', 'first supported language of the list');

sub options {
    my ($languages, $data) = @_;
    my $c = pf::UnifiedApi::Controller::Emails->new;
    $c->stash(languages => $languages);
    return $c->email_template_options($data // {});
}

is_deeply(options(['fr', 'i-default']), { __locale => 'fr_FR' }, 'Accept-Language of the request');
is_deeply(options(['i-default']), {}, 'no Accept-Language: default language');
is_deeply(options(['fr', 'i-default'], { locale => 'pt-BR' }), { __locale => 'pt_BR' }, 'locale of the payload overrides Accept-Language');
is_deeply(options(['fr', 'i-default'], { locale => 'xx' }), { __locale => 'fr_FR' }, 'unsupported locale of the payload: Accept-Language');
is_deeply(options(['xx', 'i-default']), {}, 'unsupported Accept-Language: default language');

=head1 AUTHOR

Inverse inc. <info@inverse.ca>

=head1 COPYRIGHT

Copyright (C) 2005-2026 Inverse inc.

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
