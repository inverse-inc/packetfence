package pf::web::admin;

=head1 NAME

admin.pm

=cut

use strict;
use warnings;

use Apache2::Const -compile => qw(OK DECLINED CONN_KEEPALIVE);
use Apache2::ServerRec;
use Apache2::RequestRec ();
use Apache2::RequestUtil;
use Apache2::URI;
use Apache2::Filter();
use Apache2::Request;
use Apache2::Connection;
use Data::Dumper;

use APR::URI;
use Log::Log4perl;

use pf::config;
use pf::util;
use pf::web::constants;

use constant BUFF_LEN => 1024;


#HTML attributes and tags
%pf::web::admin::linkElements = (
        'a'       => ['href', 'id'],
        'applet'  => ['archive', 'codebase', 'code'],
        'area'    => ['href'],
        'bgsound' => ['src'],
        'blockquote' => ['cite'],
        'body'    => ['background'],
        'del'     => ['cite'],
        'embed'   => ['pluginspage', 'src'],
        'form'    => ['action'],
        'frame'   => ['src', 'longdesc'],
        'iframe'  => ['src', 'longdesc'],
        'ilayer'  => ['background'],
        'img'     => ['src', 'lowsrc', 'longdesc', 'usemap'],
        'input'   => ['src', 'usemap'],
        'ins'     => ['cite'],
        'isindex' => ['action'],
        'head'    => ['profile'],
        'layer'   => ['background', 'src'],
        'link'    => ['href'],
        'object'  => ['classid', 'codebase', 'data', 'archive', 'usemap'],
        'q'       => ['cite'],
        'script'  => ['src', 'for'],
        'table'   => ['background'],
        'td'      => ['background', 'src'],
        'th'      => ['background'],
        'tr'      => ['background'],
        'xmp'     => ['href'],
);
#CSS Attributes and tags - TODO add more
%pf::web::admin::css = (
        'background-image'       => ['url'],
        'background'  => ['url'],
);


=item rewrite

Rewrite Location header to Packetfence captive portal.

=cut

sub rewrite {
    my $f = shift;
    my $r = $f->r;
    my $logger = Log::Log4perl->get_logger(__PACKAGE__);
    if ($r->content_type =~ /(text\/xml|text\/html|application\/vnd.ogc.wms_xml|text\/css|application\/x-javascript)/) {
        unless ($f->ctx) {
            my @valhead = $r->headers_out->get('Location');
            my $proto = isenabled($Config{'captive_portal'}{'secure_redirect'}) ? $HTTPS : $HTTP;
            my $value = $proto.'://'.$Config{'general'}{'hostname'}.".".$Config{'general'}{'domain'};
            my $replacementheader = 'https://'.$r->hostname.":".$r->get_server_port."/portail";
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
            #Replace links
            my $data = replace($f, $ctx->{data});
            # Skip content that should not have links
            #header_replace($f);
            $f->r->headers_out->unset('Content-Length');
            # Dump datas out
            $f->print($data);
            my $c = $f->c;
            if ($c->keepalive == Apache2::Const::CONN_KEEPALIVE && $ctx->{data} && $c->keepalives > $ctx->{keepalives}) {
                $ctx->{data} = '';
                $ctx->{pattern} = ();
                $ctx->{keepalives} = $c->keepalives;
            }
            return Apache2::Const::OK;
        }
        else {
            return Apache2::Const::DECLINED;
        }
    }
}

sub to_hash {
    no strict 'refs';

    # Lists all the entries of the WEB package then for each of them:
    my %constants;
    foreach (keys %WEB::) {
        # don't keep non scalar (hashes, lists) because using $
        next if not defined ${"WEB::$_"};
        # don't keep regex
        next if ref(${"WEB::$_"}) eq 'Regexp';
        $constants{${"WEB::$_"}} = '/portail'.${"WEB::$_"};
    }
    return %constants;
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

sub replace {
    my ($f, $data) = @_;
    my $r = $f->r;
    my $log = $r->server->log;
    my $encoding = $f->r->headers_out->{'Content-Encoding'} || '';
    # if Content-Encoding: gzip,deflate try to uncompress
    if ($encoding =~ /gzip|deflate|x-compress|x-gzip/) {
        use IO::Uncompress::AnyInflate qw(anyinflate $AnyInflateError);
        my $output = '';
        anyinflate  \$data => \$output or print STDERR "anyinflate failed: $AnyInflateError\n";
        if ($data ne $output) {
            $data = $output;
        } else {
            $encoding = '';
        }
    }
   #if ($r->content_type =~ /(text\/xml|text\/html|application\/vnd.ogc.wms_xml|text\/css|application\/x-javascript)/) {

    # Searching for all links
    my @links2 = link_replacement(\$data,$r);
    my @links = sort {length $b <=> length $a} @links2;
    foreach my $t (@links) {
        $log->debug("LINKS ".$t);
    }
    # Replace links app->url by app->name 
    my $proto;
    if ($r->subprocess_env('HTTPS')){
        $proto = "https://";
    }
    else {
        $proto = "http://";
    }

    my %component = to_hash();

    my @rewrite;

    foreach (keys %component) {
        push @rewrite, $_ ." => ". $component{$_};
    }
 
    my $ct = $f->ctx;
    $ct->{data} = '';
    foreach my $p (@rewrite) {
        push(@{$ct->{rewrite}}, $p);
    }
    $f->ctx($ct);

    #Parse all link and encode it
    my $i = 0;
    while ($links[$i]) {
        $i++;
    }
    my $ctx = $f->ctx;

    #Rewrite all links
    foreach my $p (@{$ctx->{rewrite}}) {
        my ($match, $substitute) = split (/ => /, $p);
        $log->debug("SUBSTITUTE ".$match." => ".$substitute);
        &rewrite_content(\$data, $match, $substitute);
    }
	
    # if Content-Encoding: gzip,deflate try to compress
    if ($encoding =~ /gzip|x-gzip/) {
        use IO::Compress::Gzip qw(gzip $GzipError);
        my $output = '';
        my $status = gzip \$data => \$output or die "gzip failed: $GzipError\n";
        $data = $output;
    } elsif ($encoding =~ /deflate|x-compress/) {
        use IO::Compress::Deflate qw(deflate $DeflateError);
        my $output = '';
        my $status = deflate \$ctx->{data} => \$output or die "deflate failed: $DeflateError\n";
        $data = $output;
    }
    return $data;
}

sub rewrite_content {
    my ($data, $pattern, $replacement) = @_;

    return if (!$$data);

    my $old_terminator = $/;
    $/ = '';

    # Rewrite things in code (case sensitive)
    $$data =~ s/\Q$pattern\E/$replacement/g;

    $/ = $old_terminator;
}

sub link_replacement {
    my ($data, $r) = @_;
    my $log = $r->server->log;
    return if (!$$data);

    my $old_terminator = $/;
    $/ = '';
    my @TODOS = ();
    if ($r->content_type =~ /(text\/html)/) {
        #Replace standard link into attributes of any element in html file
        foreach my $tag (keys %pf::web::admin::linkElements) {
            foreach my $attr (@{$pf::web::admin::linkElements{$tag}}) {
                while ($$data =~ m/(<$tag[\t\s]+[^>]*\b$attr=['"]*)([^'"\s>]+)/ig) {
                    if ($2 !~ /(^#(.*))|(^\/$)/) {
                        push(@TODOS, $2);
                    }
                }
            }
        }
    }
    if ($r->content_type =~ /(text\/css)/) {
        #Replace standard link into attributes of any element in css file	
        foreach my $tag (keys %pf::web::admin::css) {
            foreach my $attr (@{$pf::web::admin::css{$tag}}) {
                while ($$data =~ m/($tag[:]*[#|\s]*[a-z]*[\s]*)$attr\((.*)\)/ig) {
                    if ($2 !~ /^#/) {
                        push(@TODOS, $2);
                    }
                }
            }
        }
    }
    if ($r->content_type =~ /(text\/xml)/) {
        # Replace standard link into attributes of any element in xml file
        while ($$data =~ m|((\w+[-])+\w+/.*[\s])?\|([/>]((\w+[-])+\|(\w+/.*)+)[<"])?|ig) {
            if ($1) {
                if ($1 !~ /^#/) {
                    push(@TODOS, $1);
                }
             }
             if ($4) {
                 if ($4 !~ /^#/) {
                     push(@TODOS, $4);
                 }
             }
        }
    }
    return @TODOS;
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

