package pf::web::billinghook;

=head1 NAME

pf::web::billinghook

=cut

=head1 DESCRIPTION

pf::web::billinghook

=cut

use strict;
use warnings;
use Apache2::Const -compile => qw(OK HTTP_OK SERVER_ERROR);
use Apache2::RequestIO();
use Apache2::RequestRec();
use pf::log;
use pf::authentication qw(getAuthenticationSource);
use pf::billing::custom_hook;
use HTTP::Status qw(:constants);

my $logger = get_logger();

sub handler {
    my ($r) = @_;
    my $source = find_source_for_hook($r);
    if ($source) {
        my $content = get_content($r);
        $logger->trace(sub {"The content of is " . $content});
        my $headers = $r->headers_in;
        my $status = HTTP_OK;
        eval {
            $status = $source->handle_hook($headers, $content);
            pf::billing::custom_hook::handle_hook($source, $r->headers_in, $content);
        };
        if ($@) {
            $logger->error($@);
            $r->status(Apache2::Const::SERVER_ERROR);
            return Apache2::Const::OK;
        }
        $r->status($status);
    }
    return Apache2::Const::OK;
}

sub find_source_for_hook {
    my ($r) = @_;
    my $source;
    my $url = $r->uri;
    if ($url =~ m{/hook/billing/(.*)$}) {
        my $source_id = $1;
        $source = getAuthenticationSource($source_id);
        if($source) {
            if ($source->class ne 'billing') {
                $logger->error("source $source_id was not a billing source");
                $source = undef;
            }
            else {
                $logger->debug("Found Billing source $source_id");
            }
        }
        else {
            $logger->error("Billing source $source_id was not found");
        }
    }
    return $source;
}

sub get_content {
    my ($r)     = @_;
    my $content = '';
    my $offset  = 0;
    my $cnt     = 0;
    do {
        $cnt = $r->read($content, 8192, $offset);
        $offset += $cnt;
    } while ($cnt == 8192);
    return $content;
}

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

1;
