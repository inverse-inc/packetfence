package pf::web::admin;

=head1 NAME

admin.pm

=cut

use strict;
use warnings;

use Apache2::Const -compile => qw(OK DECLINED);
use Apache2::ServerRec;
use Apache2::RequestRec ();
use Apache2::RequestUtil;
use Apache2::URI;
use Apache2::Filter();
use Apache2::Request;

use APR::URI;
use Log::Log4perl;

use pf::config;

use constant BUFF_LEN => 1024;

=item rewrite

Rewrite Location header to Packetfence captive portal.

=cut

sub rewrite {
    my $f = shift;
    my $r = $f->r;
    my $logger = Log::Log4perl->get_logger(__PACKAGE__);
    if ($r->content_type =~ /text\/html(.*)/) {
        unless ($f->ctx) {
            my @valhead = $r->headers_out->get('Location');
            my $value = $Config{'general'}{'hostname'}.".".$Config{'general'}{'domain'};
            my $replacementheader = $r->hostname.":".$r->get_server_port."/portail";
            my $headval;
            foreach $headval (@valhead) {
                if ($headval && $headval =~ /$value/x) {
                    $headval =~ s/$value/$replacementheader/ig;
                    $r->headers_out->unset('Location');
                    $r->headers_out->set('Location' => $headval);
                }
            }
        }
        my $ctx = $f->ctx;
        while ($f->read(my $buffer, BUFF_LEN)) {
            $ctx->{data} .= $buffer;
            $ctx->{keepalives} = $f->c->keepalives;
            $f->ctx($ctx);
        }
        # Thing we do at end
        if ($f->seen_eos) {
            # Dump datas out
            $f->print($f->ctx->{data});
        }
        return Apache2::Const::OK;
    } else {
        return Apache2::Const::DECLINED;
    }
}


=item proxy_portal

Mod_proxy redirect

=cut

sub proxy_portal {
        my ($self, $r) = @_;
        my $logger = Log::Log4perl->get_logger(__PACKAGE__);
        my $s = $r->server;
        if ($r->uri =~ /portail\/(.*)/) {
             $r->headers_in->{'X-Forwarded-For'} = $management_network->{'Tip'}; 
             my $interface = $internal_nets[0];
             $r->set_handlers(PerlResponseHandler => []);
             $r->add_output_filter(\&rewrite);
             my $captiv_url = APR::URI->parse($r->pool,"http://".$interface->{'Tip'}."/".$1);
             $captiv_url->query($r->args);
             my $n = $r->notes();
             $n->add("proxy-nocanon" => "1");
             $r->filename("proxy:".$captiv_url->unparse());
             $r->proxyreq(2);
             $r->handler('proxy-server');
             return Apache2::Const::OK;
        }
        $r->set_handlers(PerlResponseHandler => 'pfappserver');
        return Apache2::Const::DECLINED;
}


=back

=head1 AUTHOR

Inverse inc. <info@inverse.ca>

=head1 COPYRIGHT
Copyright (C) 2012 Inverse inc.

=head1 LICENSE
This program is free software; you can redistribute it and/or
modify it under the terms of the GNU General Public License
as published by the Free Software Foundation; either version 2
of the License, or (at your option) any later version.
This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
GNU General Public License for more details.
You should have received a copy of the GNU General Public License
along with this program; if not, write to the Free Software
Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA 02110-1301,
USA.
=cut

1;

