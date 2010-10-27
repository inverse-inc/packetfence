#!/usr/bin/perl -w

=head1 NAME

services.t

=head1 DESCRIPTION

Exercizing pf::services and sub modules components.

=cut

use strict;
use warnings;
use diagnostics;

use Test::More tests => 9;
use Log::Log4perl;
use File::Basename qw(basename);
use lib '/usr/local/pf/lib';

Log::Log4perl->init("log.conf");
my $logger = Log::Log4perl->get_logger( basename($0) );
Log::Log4perl::MDC->put( 'proc', basename($0) );
Log::Log4perl::MDC->put( 'tid',  0 );

BEGIN { use_ok('pf::services') }
BEGIN { use_ok('pf::services::apache') }

# CONFIGURATION VALIDATION

# switches_conf_is_valid()

# modify global $conf_dir so that t/data/switches.conf will be loaded instead of conf/switches.conf
my $conf_dir = $main::pf::config::conf_dir;
$main::pf::config::conf_dir = "data/";
ok(pf::services::switches_conf_is_valid(), "switches.conf validation with a good file");
# modify global $conf_dir so that t/data/bug766/switches.conf will be loaded instead of conf/switches.conf
$main::pf::config::conf_dir = "data/bug766/";
ok(!pf::services::switches_conf_is_valid(), "switches.conf validation with a broken file (duplicate IP)");
$main::pf::config::conf_dir = $conf_dir;
# TODO add more tests around switches_conf_is_valid to test all cases


# pf::services::apache
# --------------------

# _url_parser 
my @return = pf::services::apache::_url_parser('http://packetfence.org/tests/conficker.html');
is_deeply(\@return,
    [ 'http\:\/\/packetfence\.org', 'http', 'packetfence\.org', '\/tests\/conficker\.html' ],
    "Parsing a standard URL"
);

@return = pf::services::apache::_url_parser('HTTPS://www.inverse.ca/');
is_deeply(\@return,
    [ 'https\:\/\/www\.inverse\.ca', 'https', 'www\.inverse\.ca', '\/' ],
    "Parsing an uppercase HTTPS URL with no query"
);

@return = pf::services::apache::_url_parser('invalid://url$.com');
ok(!@return, "Passed invalid URL expecting undef");

# generate_passthrough_rewrite_proxy_config
my %sample_config = (
    "packetfencebugs" => 'http://www.packetfence.org/bugs/',
    "invalid" => "bad-url.ca",
    "inverse" => "http://www.inverse.ca/"
);
@return = generate_passthrough_rewrite_proxy_config(%sample_config);
is_deeply(\@return,
    [
        [ '  # AUTO-GENERATED mod_rewrite rules for PacketFence Passthroughs', 
        '  # Rewrite rules generated for passthrough packetfencebugs',
        '  RewriteCond %{HTTP_HOST} ^www\\.packetfence\\.org$',
        '  RewriteCond %{REQUEST_URI} ^\\/bugs\\/',
        '  RewriteRule ^(.*)$ http\\:\\/\\/www\\.packetfence\\.org/$1 [P]',
        '  # Rewrite rules generated for passthrough inverse',
        '  RewriteCond %{HTTP_HOST} ^www\\.inverse\\.ca$',
        '  RewriteCond %{REQUEST_URI} ^\\/',
        '  RewriteRule ^(.*)$ http\\:\\/\\/www\\.inverse\\.ca/$1 [P]',
        '  # End of AUTO-GENERATED mod_rewrite rules for PacketFence Passthroughs'],
        [ '  # NO auto-generated mod_rewrite rules for PacketFence Passthroughs' ]
    ],
    "Correct passthrough configuration generated"
);

# generate_passthrough_rewrite_proxy_config
my @sample_config = (
    {
        "vid" => '101',
        "url" => 'http://www.packetfence.org/'
    },
    {
        "vid" => '102',
        "url" => 'bad-url.ca'
    },
    {
        "vid" => '103',
        "url" => '/content/local'
    },
    {
        "vid" => '104',
        "url" => 'http://www.packetfence.org/tests/conficker.html'
    }
);
my $return = generate_remediation_rewrite_proxy_config(@sample_config);
is_deeply($return, [
    '  # AUTO-GENERATED mod_rewrite rules for PacketFence Remediation',
    '  # Rewrite rules generated for violation 101 external\'s URL',
    '  RewriteCond %{HTTP_HOST} ^www\\.packetfence\\.org$',
    '  RewriteCond %{REQUEST_URI} ^\\/',
    '  RewriteRule ^(.*)$ http\\:\\/\\/www\\.packetfence\\.org/$1 [P]',
    '  # Rewrite rules generated for violation 104 external\'s URL',
    '  RewriteCond %{HTTP_HOST} ^www\\.packetfence\\.org$',
    '  RewriteCond %{REQUEST_URI} ^\\/tests\\/conficker\\.html',
    '  RewriteRule ^(.*)$ http\\:\\/\\/www\\.packetfence\\.org/$1 [P]',
    '  # End of AUTO-GENERATED mod_rewrite rules for PacketFence Remediation',
    ], "Correct remediation reverse proxying configuration generated"
);

=head1 AUTHOR

Olivier Bilodeau <obilodeau@inverse.ca>
        
=head1 COPYRIGHT
        
Copyright (C) 2010 Inverse inc.

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

