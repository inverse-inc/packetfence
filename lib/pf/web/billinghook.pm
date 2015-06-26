package pf::web::billinghook;

=head1 NAME

pf::web::billinghook add documentation

=cut

=head1 DESCRIPTION

pf::web::billinghook

=cut

use strict;
use warnings;
use Apache2::Const -compile => qw(
    OK DECLINED HTTP_UNAUTHORIZED HTTP_NOT_IMPLEMENTED
    HTTP_UNSUPPORTED_MEDIA_TYPE HTTP_PRECONDITION_FAILED
    HTTP_NO_CONTENT HTTP_NOT_FOUND SERVER_ERROR HTTP_OK
    HTTP_INTERNAL_SERVER_ERROR
);
use Apache2::RequestIO();
use Apache2::RequestRec();
use pf::log;
use pf::authentication qw(getAuthenticationSource);

my $logger = get_logger();

sub handler {
    my ($r) = @_;
    my $source = find_source_for_hook($r);
    if ($source) {
        my $content = get_content($r);
        my $status = $source->hook($r->headers_in, $content);
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

Copyright (C) 2005-2015 Inverse inc.

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

