#!/usr/bin/perl

=head1 NAME

generatesyslogconfig-inputs

=head1 DESCRIPTION

unit test for the inputs configuration of pf::cmd::pf::generatesyslogconfig

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
use File::Temp qw(tempfile);
use pf::cmd::pf::generatesyslogconfig;

#This test will running last
use Test::NoWarnings;

sub main_config {
    my ($content) = @_;
    my ($fh, $file) = tempfile(UNLINK => 1);
    print $fh $content;
    close $fh;
    $pf::cmd::pf::generatesyslogconfig::RSYSLOG_MAIN_CONFIG = $file;
}

# Debian: imuxsock loaded by the main configuration, not imjournal
main_config(qq{module(load="imuxsock")\nmodule(load="imklog")\n});
my $inputs = pf::cmd::pf::generatesyslogconfig::inputs_config();
like($inputs, qr/module\(load="imjournal" StateFile="imjournal\.state"/, 'imjournal is loaded with a state file');
like($inputs, qr/IgnorePreviousMessages="on"/, 'the journal is not read again without a state file');
like($inputs, qr/Ratelimit\.Interval="0" Ratelimit\.Burst="0"/, 'imjournal rate-limiting is disabled');

# EL: imjournal already loaded by the main configuration
main_config(qq{module(load="imuxsock" SysSock.Use="off")\nmodule(load="imjournal"\n       StateFile="imjournal.state")\n});
is(pf::cmd::pf::generatesyslogconfig::inputs_config(), '', 'imjournal is not loaded twice');

main_config(qq{\$ModLoad imjournal\n});
is(pf::cmd::pf::generatesyslogconfig::inputs_config(), '', 'imjournal loaded with the legacy syntax is detected');

my $legacy = <<'CONF';
$ModLoad imuxsock # provides support for local system logging (e.g. via logger command)
$ModLoad imjournal # provides access to the systemd journal
# Disable rate-limiting of syslog
$SystemLogRateLimitInterval 0
$SystemLogRateLimitBurst 0
$imjournalRatelimitInterval 0
$imjournalRatelimitBurst 0
$EscapeControlCharactersOnReceive off
$FileGroup pf
CONF

is(
    pf::cmd::pf::generatesyslogconfig::remove_legacy_inputs_config($legacy),
    "# Disable rate-limiting of syslog\n\$EscapeControlCharactersOnReceive off\n\$FileGroup pf\n",
    'legacy input directives of previous templates are removed, the other directives are kept'
);

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

