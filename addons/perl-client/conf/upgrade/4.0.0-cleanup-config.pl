#!/usr/bin/perl

=head1 NAME

4.0.0-cleanup-config.pl

=cut

=head1 DESCRIPTION

Cleans up deprecated fingerbank.conf parameters
This script is idempotent so it can be called on every upgrade without any issues

=cut

use lib qw ( /usr/local/fingerbank/lib/ /usr/local/pf/lib_perl/lib/perl5/ );

use fingerbank::Config;
use fingerbank::Log;

fingerbank::Log::init_logger;

fingerbank::Config::read_config;

my $tConfig = tied(%fingerbank::Config::Config);

$tConfig->delval("upstream", "interrogate");
$tConfig->delval("upstream", "interrogate_url");
$tConfig->delval("upstream", "submit_url");
$tConfig->delval("upstream", "db_url");

$tConfig->delval("query", "use_redis");
$tConfig->delval("query", "use_tcp_fingerprinting");

$tConfig->DeleteSection("tcp_fingerprinting");
$tConfig->DeleteSection("redis");
$tConfig->DeleteSection("mysql");

$tConfig->RewriteConfig() || die "Couldn't rewrite Fingerbank settings";

# Rewrite the config using the Fingerbank lib to cleanup any defaults
fingerbank::Config::write_config;

print "Finished running 4.0.0 configuration migration\n";

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

