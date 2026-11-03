#!/usr/bin/perl

=head1 NAME

radiusd_child

=head1 DESCRIPTION

Generation of the realm and oauth2 (Azure AD TTLS-PAP) configuration by
pf::services::manager::radiusd_child. FreeRADIUS sets the Realm attribute of
a regex realm to the domain sent by the user, so the oauth2 settings of a
regex realm are written in a separate oauth2_realm section, selected in the
packetfence-tunnel authorize (GitHub #9154).

=cut

use strict;
use warnings;

BEGIN {
    use lib qw(/usr/local/pf/t);
    use setup_test_config;
}

use Test::More tests => 17;
use Test::NoWarnings;

use_ok('pf::services::manager::radiusd_child');

{
    package FakeAzureADSource;
    sub new { bless {}, shift }
    sub client_id { 'client-id-9154' }
    sub client_secret { 'client-secret-9154' }
    sub oauth_url { 'https://login.microsoftonline.com' }
}

{
    package FakeTT;
    sub new { bless {}, shift }
    # Keeps a copy of the tags of each template: generate_radiusd_proxy processes several
    sub process { my ($self, $template, $tags, $out) = @_; $template =~ s{.*/}{}; $self->{$template} = { %$tags }; return 1 }
    sub error { '' }
}

{
    no warnings qw(redefine once);
    *pf::services::manager::radiusd_child::getAuthenticationSource = sub { FakeAzureADSource->new };
    *pf::authentication::getAuthenticationSourcesByType = sub { [] };
}

# A regex realm and a plain realm using Azure AD TTLS-PAP, a regex realm without it
local *pf::config::ConfigOrderedRealm = [qw(rx9154 plain.example rxnone)];
local *pf::config::ConfigRealm = {
    'rx9154'        => { regex => 'rx9154\.example$', azuread_source_ttls_pap => 'AzureAD' },
    'plain.example' => { azuread_source_ttls_pap => 'AzureAD' },
    'rxnone'        => { regex => 'other\.example$' },
};

# Top-level sections of a generated configuration: [header, body]
sub top_level_sections {
    my ($config) = @_;
    my (@sections, $depth, $header, $body);
    $depth = 0;
    for my $line (split /\n/, $config) {
        my $opens = () = $line =~ /\{/g;
        my $closes = () = $line =~ /\}/g;
        if ($depth == 0 && $opens) {
            ($header = $line) =~ s/\s*\{.*$//;
            $body = '';
        }
        elsif ($depth > 0) {
            $body .= "$line\n";
        }
        $depth += $opens - $closes;
        return undef if $depth < 0;
        push @sections, [$header, $body] if $depth == 0 && ($opens || $closes);
    }
    return $depth == 0 ? \@sections : undef;
}

sub section {
    my ($sections, $header) = @_;
    my @found = grep { $_->[0] eq $header } @$sections;
    return @found == 1 ? $found[0][1] : undef;
}

# --- generate_radiusd_proxy -------------------------------------------------
my $tt = FakeTT->new;
pf::services::manager::radiusd_child->generate_radiusd_proxy($tt);
ok($tt->{'proxy.conf.inc'}, "proxy.conf.inc tags are generated");
my $sections = top_level_sections($tt->{'proxy.conf.inc'}{config});
ok($sections, "the realm configuration has balanced braces");
$sections //= [];

my $regex_realm = section($sections, 'realm "~rx9154\.example$"');
ok(defined $regex_realm, "the regex realm is a top-level section");
unlike($regex_realm // '', qr/oauth2/, "no oauth2 settings inside the regex realm section");

my $oauth2_realm = section($sections, 'oauth2_realm rx9154');
ok(defined $oauth2_realm, "the oauth2 settings of the regex realm are in a top-level oauth2_realm section");
like($oauth2_realm // '', qr{^oauth2 \{$}m, "the oauth2_realm section holds an oauth2 subsection");
like($oauth2_realm // '', qr{discovery = "https://login\.microsoftonline\.com/%\{Realm\}/v2\.0"}, "discovery URL uses the Realm sent by the user");
like($oauth2_realm // '', qr{client_id = "client-id-9154"}, "client_id comes from the Azure AD source");

my $plain_realm = section($sections, 'realm plain.example');
like($plain_realm // '', qr{^oauth2 \{$}m, "the oauth2 settings of a plain realm stay inside its realm section");
is(scalar(grep { $_->[0] =~ /^oauth2_realm / } @$sections), 1, "only the regex realm with Azure AD gets an oauth2_realm section");
unlike(section($sections, 'realm "~other\.example$"') // 'missing oauth2', qr/oauth2/, "a regex realm without Azure AD has no oauth2 settings");

# --- generate_ldap_choice ---------------------------------------------------
my ($authorize, $auth_type, $edir) = ('', '', '');
pf::services::manager::radiusd_child::generate_ldap_choice(\$authorize, \$auth_type, \$edir);
like($authorize, qr{if \(Realm =~ /rx9154\\\.example\$/\) \{\s*update control \{\s*&OAuth2-Config-Section := "oauth2_realm\[rx9154\]"\s*\}\s*oauth2\s*\}}, "the regex realm selects its oauth2_realm section before calling oauth2");
like($authorize, qr{elsif \(Realm =~ /\^plain\.example\$/\) \{\s*oauth2\s*\}}, "a plain realm calls oauth2 without selecting a section");
is(() = $authorize =~ /OAuth2-Config-Section/g, 1, "the section is only selected for the regex realm");
is(() = $authorize =~ /^\s*if \(/mg, 1, "one if, then elsif for the other realms");

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
