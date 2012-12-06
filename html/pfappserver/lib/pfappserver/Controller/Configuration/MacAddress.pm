package pfappserver::Controller::Configuration::MacAddress;

=head1 NAME

pfappserver::Controller::Configuration::MacAddress - Catalyst Controller

=head1 DESCRIPTION

Catalyst Controller.

=cut

use strict;
use warnings;

use Date::Parse;
use HTTP::Status qw(:constants is_error is_success);
use Moose;
use namespace::autoclean;
use POSIX;
use URI::Escape;

use pf::authentication;
use pf::os;
use pf::util qw(load_oui download_oui);
# imported only for the $TIME_MODIFIER_RE regex. Ideally shouldn't be 
# imported but it's better than duplicating regex all over the place.
use pf::config;
use Data::Dumper;
use pfappserver::Form::Config::Pf;

BEGIN {extends 'pfappserver::Base::Controller::Base'; }

=head2 index

=cut

my %VALID_PARAMS = (
    page_num => 1,
    by => 1,
    direction => 1,
    filter => 1
);

sub index : Path :Args() {
    my ( $self, $c,%args ) = @_;
    %args = map { $_ => $args{$_}  } grep { exists $VALID_PARAMS{$_}  } keys %args;
    $c->stash(%args);
    $self->_list_items( $c, 'MacAddress' );
}

sub update : Local : Args(0) {
    my ( $self, $c ) = @_;
    $c->stash->{current_view} = 'JSON';
    my ($status,$status_msg) = download_oui();
    load_oui(1);
    $c->response->status($status);
    $c->stash->{status_msg} = $status_msg;
}

=head1 COPYRIGHT

Copyright (C) 2012 Inverse inc.

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

__PACKAGE__->meta->make_immutable;

1;
