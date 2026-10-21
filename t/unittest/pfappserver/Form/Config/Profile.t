#!/usr/bin/perl

=head1 NAME

Profile

=head1 DESCRIPTION

unit test for the connection profile form: the warning when preregistration is
enabled while no authentication source creates local accounts

=cut

use strict;
use warnings;

BEGIN {
    #include test libs
    use lib qw(/usr/local/pf/t);
    #Module for overriding configuration paths
    use setup_test_config;
}

use Test::More tests => 7;

#This test will running last
use Test::NoWarnings;
use pfappserver::Form::Config::Profile::Default;
use pf::config qw(%ConfigPortalModules);

# The sources of the test configuration don't create local accounts, except the
# ones listed here
my %CREATES_LOCAL_ACCOUNT;
{
    package FakeSource;
    sub new { my ($class, %args) = @_; bless {%args}, $class }
    sub id { $_[0]{id} }
    sub class { 'internal' }
    sub type { 'Null' }
    sub create_local_account { $CREATES_LOCAL_ACCOUNT{$_[0]{id}} ? 'yes' : 'no' }
}
my $real_get_source = \&pf::authentication::getAuthenticationSource;
{
    no warnings qw(redefine once);
    *pf::authentication::getAuthenticationSource = sub {
        my ($id) = @_;
        return $id =~ /^prereg_/ ? FakeSource->new(id => $id) : $real_get_source->($id);
    };
}

sub warnings_for {
    my (%params) = @_;
    # the default profile form, without the filters; the check is shared with the other profiles
    my $form = pfappserver::Form::Config::Profile::Default->new(id => 'default');
    $form->process(params => { id => 'default', %params });
    return [ map { $_->{message} } $form->all_pf_warnings ];
}

is_deeply(warnings_for(sources => ['prereg_none'], preregistration => 'disabled'), [], 'No warning without preregistration');

my $warnings = warnings_for(sources => ['prereg_none'], preregistration => 'enabled');
is(scalar @$warnings, 1, 'Preregistration with a source that does not create local accounts warns');
like($warnings->[0] // '', qr/Create local account/, 'with what to change');

$CREATES_LOCAL_ACCOUNT{prereg_creates} = 1;
is_deeply(warnings_for(sources => ['prereg_none', 'prereg_creates'], preregistration => 'enabled'), [], 'No warning when one of the sources creates local accounts');

# A portal module under the root module with its own source
{
    local $ConfigPortalModules{prereg_root} = { type => 'Root', modules => ['prereg_module'] };
    local $ConfigPortalModules{prereg_module} = { type => 'Authentication::Null', source_id => 'prereg_creates' };
    is_deeply(warnings_for(sources => ['prereg_none'], root_module => 'prereg_root', preregistration => 'enabled'), [], 'The sources of the portal modules count');
    local $ConfigPortalModules{prereg_module} = { type => 'Authentication::Null', source_id => 'prereg_none' };
    is(scalar @{warnings_for(sources => ['prereg_none'], root_module => 'prereg_root', preregistration => 'enabled')}, 1, 'and warn when none of them creates local accounts');
}

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
