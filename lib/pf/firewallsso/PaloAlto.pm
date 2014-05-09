package pf::firewallsso::PaloAlto;

=head1 NAME

pf::firewallsso::PaloAlto

=head1 SYNOPSIS

The pf::firewallsso::PaloAlto module implements an object oriented interface
to access and manage Aruba Wireless Controllers.

=cut


use strict;
use warnings;

use base ('pf::firewallsso');

use POSIX;
use Log::Log4perl;

use pf::config;
sub description { 'PaloAlto Firewall' }
use pf::node qw(node_view);
use LWP::UserAgent;
use HTTP::Request::Common;

#Export environement variables for LWP
$ENV{'PERL_LWP_SSL_VERIFY_HOSTNAME'} = 0;

sub action {
    my ($self,$firewall_conf,$method,$mac,$ip) = @_;
    my $logger = Log::Log4perl::get_logger(ref($self));

    if ($method eq 'Start') {
        my $node_info = node_view($mac);

        if (defined($node_info) && (ref($node_info) eq 'HASH') && $node_info->{'status'} eq $pf::node::STATUS_REGISTERED) {
            my $message = <<"XML";
                <uid-message>
                    <version>1.0</version>
                    <type>update</type>
                    <payload>
                        <login>
                            <entry name=\"$node_info->{'pid'}\" ip=\"$ip\"/>
                        </login>
                    </payload>
               </uid-message>
XML
            my $webpage = "https://".$firewall_conf."/api/?type=user-id&action=set&key=".$ConfigFirewallSSO{$firewall_conf}->{'key'};
            my $ua = LWP::UserAgent->new;
            my $response = $ua->post($webpage, Content => [ cmd => $message ]);
            if ($response->is_success) {
                $logger->debug("Node registered, allowed to pass Firewall");
                return 1;
            } else {
                $logger->error("XML send error :".$response->status_line);
                return 0;
            }
        }
    }
    return 0;
}

=head1 AUTHOR

Inverse inc. <info@inverse.ca>

Minor parts of this file may have been contributed. See CREDITS.

=head1 COPYRIGHT

Copyright (C) 2005-2014 Inverse inc.

Copyright (C) 2005 Kevin Amorin

Copyright (C) 2005 David LaPorte

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

# vim: set shiftwidth=4:
# vim: set expandtab:
# vim: set backspace=indent,eol,start:
