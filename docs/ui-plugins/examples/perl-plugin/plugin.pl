#!/usr/bin/perl

=head1 NAME

plugin.pl - a complete admin UI plugin service in Perl

=head1 SYNOPSIS

  # on the host of api-frontend
  plugin.pl --listen http://127.0.0.1:8093

  # from another host: HTTPS, with a certificate valid for --host
  plugin.pl --listen 'https://*:8443?cert=notes.crt&key=notes.key' --host notes.example --port 8443

=head1 DESCRIPTION

The scaffold of docs/ui-plugins/SCAFFOLDING.md: a Mojolicious (shipped with
PacketFence) service that serves its manifest (manifest.json, next to this
script) and the API of its page, a collection of notes kept in memory, then
registers itself with the PacketFence Perl accessors (pf::ui_plugins) and
deregisters itself on SIGTERM or SIGINT.

=cut

use strict;
use warnings;
use lib qw(/usr/local/pf/lib /usr/local/pf/lib_perl/lib/perl5);
use FindBin;
use Getopt::Long;
use File::Slurp qw(read_file);
use JSON::MaybeXS qw(decode_json);
use Mojolicious::Lite;
use Mojo::IOLoop;
use Mojo::Server::Daemon;
use pf::error qw(is_error);
use pf::ui_plugins;

my %options = (listen => 'http://127.0.0.1:8093', name => 'notes-perl', register => 1);
GetOptions(\%options, 'listen=s', 'name=s', 'host=s', 'port=i', 'register!')
  or die "usage: $0 [--listen URL] [--name NAME] [--host HOST] [--port PORT] [--no-register]\n";

my $manifest = read_file("$FindBin::Bin/manifest.json");

# the data of the plugin: a real plugin keeps it in its own storage
my %notes = (welcome => { id => 'welcome', text => 'Hello from the Perl plugin' });

# the admin PacketFence checked: never the admin token
sub admin {
    my ($c) = @_;
    my %actions = map { $_ => 1 } split /,/, ($c->req->headers->header('X-PacketFence-Admin-Actions') // '');
    return { username => $c->req->headers->header('X-PacketFence-Username'), actions => \%actions };
}

# the page of a list or a search, in the format of the PacketFence API
sub page {
    my ($list, $cursor, $limit) = @_;
    $cursor = 0 if !$cursor || $cursor < 0;
    $limit = 25 if !$limit || $limit <= 0;
    $cursor = @$list if $cursor > @$list;
    my $end = $cursor + $limit > @$list ? scalar @$list : $cursor + $limit;
    my %page = (items => [ @$list[$cursor .. $end - 1] ], prevCursor => $cursor, total_count => scalar @$list, status => 200);
    $page{nextCursor} = $end if $end < @$list;
    return \%page;
}

sub sorted { [ map { $notes{$_} } sort keys %notes ] }

# the "value"s of a search query of the UI
sub search_values {
    my ($node, $values) = @_;
    if (ref $node eq 'HASH') {
        push @$values, lc $node->{value} if defined $node->{value} && !ref $node->{value} && length $node->{value};
        search_values($_, $values) for values %$node;
    } elsif (ref $node eq 'ARRAY') {
        search_values($_, $values) for @$node;
    }
    return $values;
}

# PacketFence passes only JSON to the admin
sub message {
    my ($c, $status, $text) = @_;
    $c->render(status => $status, json => { message => $text, status => $status });
}

get '/manifest.json' => sub {
    my ($c) = @_;
    $c->res->headers->content_type('application/json');
    $c->render(data => $manifest);
};

# listOptions, itemOptions: the meta of the form fields (none here)
options '/notes' => sub { $_[0]->render(json => { meta => {} }) };
options '/notes/:id' => sub { $_[0]->render(json => { meta => {} }) };

# list
get '/notes' => sub {
    my ($c) = @_;
    $c->render(json => page(sorted(), $c->param('cursor'), $c->param('limit')));
};

# search: the query of the UI, here a substring of any value
post '/notes/search' => sub {
    my ($c) = @_;
    my $query = $c->req->json // {};
    my $values = search_values($query->{query}, []);
    my @found = grep {
        my $text = lc "$_->{id} $_->{text}";
        !grep { index($text, $_) < 0 } @$values
    } @{ sorted() };
    $c->render(json => page(\@found, $query->{cursor}, $query->{limit}));
};

# create: PacketFence already checked api.create.can ("create syslog")
post '/notes' => sub {
    my ($c) = @_;
    my $note = $c->req->json;
    if (ref $note ne 'HASH' || !defined $note->{id} || $note->{id} eq '') {
        return $c->render(status => 422, json => { message => 'A name is required', errors => [ { field => 'id', message => 'required' } ], status => 422 });
    }
    return message($c, 409, 'This note already exists') if exists $notes{ $note->{id} };
    $notes{ $note->{id} } = { id => "$note->{id}", text => "" . ($note->{text} // '') };
    $c->app->log->info("note $note->{id} created by " . (admin($c)->{username} // '?'));
    $c->render(status => 201, json => { id => $note->{id}, message => 'Note created', status => 201 });
};

# item
get '/notes/:id' => sub {
    my ($c) = @_;
    my $note = $notes{ $c->param('id') } // return message($c, 404, 'No such note');
    $c->render(json => { item => $note, status => 200 });
};

# update (PATCH): PacketFence already checked api.update.can
patch '/notes/:id' => sub {
    my ($c) = @_;
    my $id = $c->param('id');
    my $note = $notes{$id} // return message($c, 404, 'No such note');
    my $data = $c->req->json;
    return message($c, 422, 'Invalid JSON') if ref $data ne 'HASH';
    $note->{text} = "$data->{text}" if defined $data->{text};
    message($c, 200, 'Note updated');
};

# delete: PacketFence already checked api.delete.can
del '/notes/:id' => sub {
    my ($c) = @_;
    my $id = $c->param('id');
    return message($c, 404, 'No such note') if !exists $notes{$id};
    delete $notes{$id};
    message($c, 200, 'Note deleted');
};

# the registration: where PacketFence reaches this service
my $listen = Mojo::URL->new($options{listen} =~ s/\*/0.0.0.0/r);
my %registration = (
    name => $options{name},
    host => $options{host} // $listen->host,
    port => $options{port} // $listen->port,
);
my ($ok, $error) = pf::ui_plugins::validate(\%registration);
die "$error\n" if !$ok;

my $daemon = Mojo::Server::Daemon->new(app => app, listen => [ $options{listen} ], silent => 1);
$daemon->start;

# register once the service answers: the credentials of the database come
# from the PacketFence configuration
if ($options{register}) {
    my ($status, $error) = pf::ui_plugins::register(\%registration);
    die "$error\n" if is_error($status);
}
app->log->info("UI plugin $registration{name} at $registration{host}:$registration{port}");

my $stop = sub {
    if ($options{register}) {
        my ($status, $error) = pf::ui_plugins::deregister($registration{name});
        app->log->error($error) if is_error($status);
    }
    app->log->info("UI plugin $registration{name} stopped");
    Mojo::IOLoop->stop;
};
local $SIG{TERM} = $stop;
local $SIG{INT}  = $stop;
# Perl delivers a signal between two operations: wake the loop up regularly
Mojo::IOLoop->recurring(1 => sub { });
Mojo::IOLoop->start;

=head1 AUTHOR

Inverse inc. <info@inverse.ca>

=head1 COPYRIGHT

Copyright (C) 2005-2026 Inverse inc.

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
