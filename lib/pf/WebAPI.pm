package pf::WebAPI;

=head1 NAME

WebAPI - Apache mod_perl wrapper to PFAPI (below).

=cut

use strict;
use warnings;

use Apache2::MPM ();
use Apache2::RequestRec;
use pf::log;
use ModPerl::Util;

use pf::config;
use pf::api;
use pf::client;
pf::client::setClient("pf::api::local");

#uncomment for more debug information
#use SOAP::Lite +trace => [ fault => \&log_faults ];
use SOAP::Transport::HTTP;
use pf::WebAPI::MsgPack;
use pf::WebAPI::JSONRPC;
use pf::WebAPI::REST;


# set proper logger tid based on if we are run from mod_perl or not
if (exists($ENV{MOD_PERL})) {
    if (Apache2::MPM->is_threaded) {
        require APR::OS;
        # apache threads
        Log::Log4perl::MDC->put('tid', APR::OS::current_thread_id());
    } else {
        # httpd processes
        Log::Log4perl::MDC->put('tid', $$);
    }
} else {
    # process threads
    require threads;
    Log::Log4perl::MDC->put('tid', threads->self->tid());
}

my $server_soap = SOAP::Transport::HTTP::Apache->dispatch_to('PFAPI');
my $server_msgpack = pf::WebAPI::MsgPack->new({dispatch_to => 'pf::api'});
my $server_jsonrpc = pf::WebAPI::JSONRPC->new({dispatch_to => 'pf::api'});
my $server_rest = pf::WebAPI::REST->new({dispatch_to => 'pf::api'});

sub handler {
    my ($r) = @_;
    pf::client::setClient("pf::api::local");
    my $logger = get_logger();
    if (defined($r->headers_in->{Request})) {
        $r->user($r->headers_in->{Request});
    }
    my $content_type = $r->headers_in->{'Content-Type'};
    $logger->debug("$content_type");
    if( $content_type eq 'application/x-msgpack') {
        return $server_msgpack->handler($r);
    } elsif (pf::WebAPI::JSONRPC::allowed($content_type)) {
        return $server_jsonrpc->handler($r);
    } elsif (pf::WebAPI::REST::allowed($content_type)) {
        return $server_rest->handler($r);
    } else {
        return $server_soap->handler($r);
    }
}

sub log_faults {
    my $logger = get_logger();
    $logger->info(@_);
}

package PFAPI;
use base qw(pf::api);

=head1 AUTHOR

Inverse inc. <info@inverse.ca>

=head1 COPYRIGHT

Copyright (C) 2005-2019 Inverse inc.

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
