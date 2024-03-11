#!/usr/bin/perl

=head1 NAME

fingerbank.pl

=head1 DESCRIPTION

Mock the fingerbank API fingerbank.pl

=cut

use strict;
use warnings;
use lib qw(
    /usr/local/pf/lib
    /usr/local/pf/lib_perl/lib/perl5
);
use Mojolicious::Lite -signatures;
use URI::Escape qw(uri_escape);


get '/api/v2/download/db' => sub ($c) {
    my $headers = $c->res->headers;
    $headers->add('Content-Disposition', 'attachment; filename="fingerbank.db"');
    $headers->content_type('application/sqlite3');
    $c->reply->file('/usr/local/pf/t/data/fingerbank.db');
};

any '/*dapath' => sub ($c) {
    my $req = $c->req;
    return $c->rendered( 204 ) if $req->method eq 'OPTIONS';
    my $variant = variant($req);
    return $c->render(
        template => join( '/', uc $req->method, $c->stash('dapath') ),
        variant  => $variant,
        format   => 'json',
    );

};

sub variant ($req) {
    return undef;
}

hook before_server_start => sub ($server, $app) {
    $server->daemonize;
};

app->start;

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

__DATA__
