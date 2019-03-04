package pfappserver::View::JSON;

use strict;
use base 'Catalyst::View::JSON';

=head2 process

Override the content type for IE

=cut

sub process {
    my ($self, $c) = @_;
    $self->SUPER::process($c);
    if( my $content_type = $c->stash->{json_view_content_type}) {
        my $res = $c->res;
        my $encoding = $self->encoding || 'utf-8';
        $res->content_type("$content_type; charset=$encoding");
        if($encoding eq 'utf-8' && $content_type eq 'text/plain') {
            my $user_agent = $c->req->user_agent || '';
            #Remove the utf-8 bom for safari
            if ($user_agent =~ m/\bSafari\b/ and $user_agent !~ m/\bChrome\b/) {
                use bytes;
                my $output = $res->output();
                $output =~ s/^(?:\357\273\277|\377\376\0\0|\0\0\376\377|\376\377|\377\376)//;
                #$output =~ s/\x{FEFF}//;
                $res->output($output);
            }
        }
    }
};

=head1 NAME

pfappserver::View::JSON - Catalyst JSON View

=head1 SYNOPSIS

See L<pfappserver>

=head1 DESCRIPTION

Catalyst JSON View.

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
