package pfappserver::Base::Controller;

=head1 NAME

package pfappserver::Base::Controller;

=head1 DESCRIPTION

The base controller

=cut

use strict;
use warnings;
use Date::Parse;
use HTTP::Status qw(:constants is_error is_success);
use Moose;
use Moose::Util qw(apply_all_roles);
use namespace::autoclean;
use POSIX;
use URI::Escape::XS;
use pfappserver::Base::Action::AdminRole;
use pfappserver::Base::Action::SimpleSearch;

use pf::util qw(load_oui download_oui);
# imported only for the $TIME_MODIFIER_RE regex. Ideally shouldn't be
# imported but it's better than duplicating regex all over the place.
use pf::config;
use pf::config::cached;
use Moose;
use Class::MOP;
use Catalyst::Utils;
use Moose::Meta::Class;
use String::RewritePrefix 0.004;
use MooseX::Types::Moose qw/ArrayRef Str RoleName/;
use List::Util qw(first);

use File::Spec::Functions;

BEGIN { extends 'Catalyst::Controller'; }

our %VALID_PARAMS =
  (
   page_num => 1,
   by => 1,
   direction => 1,
   filter => 1,
   start => 1,
   end => 1,
   column => 1,
);

=head1 METHODS

=head2 auto

Allow only authenticated users

=cut

sub auto :Private {
    my ($self, $c) = @_;

    unless ($c->user_in_realm('admin')) {
        $c->response->status(HTTP_UNAUTHORIZED);
        $c->response->location($c->req->referer);
        $c->stash->{template} = 'admin/unauthorized.tt';
        $c->detach();
        return 0;
    }

    return 1;
}

=head2 valid_param

Subroutines with the 'SimpleSearch' attribute will automatically stash
URL parameters listed in our VALID_PARAMS hash.

=cut

sub valid_param {
    my ($self, $key) = @_;
    return exists $VALID_PARAMS{$key};
}

=head2 _parse_SimpleSearch_attr

Customize the parsing of the 'SimpleSearch' subroutine attribute. Returns a hash with the attribute value.

See https://metacpan.org/module/Catalyst::Controller#parse_-name-_attr

=cut

sub _parse_SimpleSearch_attr {
    my ($self, $c, $name, $value) = @_;
    return SimpleSearch => $value;
}

=head2 _parse_AdminRole_attr

Customize the parsing of the 'AdminRole' subroutine attribute. Returns a hash with the attribute value.

See https://metacpan.org/module/Catalyst::Controller#parse_-name-_attr

=cut

sub _parse_AdminRole_attr {
    my ($self, $c, $name, $value) = @_;
    return AdminRole => $value;
}

=head2 _parse_AdminRoleAny_attr

Customize the parsing of the 'AdminRoleAny' subroutine attribute. Returns a hash with the attribute value.

See https://metacpan.org/module/Catalyst::Controller#parse_-name-_attr

=cut

sub _parse_AdminRoleAny_attr {
    my ($self, $c, $name, $value) = @_;
    return AdminRoleAny => $value;
}

=head2 around create_action

Construction of a new Catalyst::Action.

See https://metacpan.org/module/Catalyst::Controller#self-create_action-args

=cut

around create_action => sub {
    my ($orig, $self, %args) = @_;

    my $model;
    my $action = $self->$orig(%args);
    unless ($args{name} =~ /^_(DISPATCH|BEGIN|AUTO|ACTION|END)$/) {
        my @roles;
        if(@{ $args{attributes}->{SimpleSearch} || [] }) {
            push @roles,'pfappserver::Base::Action::SimpleSearch';
        }
        if(@{ $args{attributes}->{AdminRole} || $args{attributes}->{AdminRoleAny} || [] }) {
            push @roles,'pfappserver::Base::Action::AdminRole';
        }
        apply_all_roles($action,@roles) if @roles;
    }
    return $action;
};

=head2 _list_items

=cut

sub _list_items {
    my ( $self, $c, $model_name ) = @_;
    my ( $filter, $orderby, $orderdirection, $status, $result, $items_ref );
    my $model       = $c->model($model_name);
    my $field_names = $model->field_names();
    my $page_num    = $c->stash->{'page_num'} || 1;
    my $per_page    = $c->stash->{'per_page'} || 25;
    my $limit_clause =
        "LIMIT " . ( ( $page_num - 1 ) * $per_page ) . "," . $per_page;
    my %params = ( limit => $limit_clause );

    if ( exists( $c->stash->{'filter'} ) ) {
        # A simple search
        $filter = $c->stash->{'filter'};
        $params{'where'} = { type => 'any', like => $filter };
        $c->stash->{filter} = $filter;
    }

    $orderby = $c->stash->{'by'};
    unless ( $orderby && grep { $_ eq $orderby } (@$field_names) ) {
        $orderby = $field_names->[0];
    }
    $orderdirection = $c->stash->{'direction'};
    unless ( $orderdirection && grep { $_ eq $orderdirection } ( 'asc', 'desc' ) ) {
        $orderdirection = 'asc';
    }
    $params{'orderby'}     = "ORDER BY $orderby $orderdirection";
    $c->stash->{by}        = $orderby;
    $c->stash->{direction} = $orderdirection;

    my $count;
    ( $status, $result ) = $model->search(%params);
    if ( is_success($status) ) {
        $items_ref = $result;
       ( $status, $count ) = $model->countAll(%params);
    }
    if ( is_success($status) ) {
        $items_ref = $result;
        $c->stash->{count}       = $count;
        $c->stash->{page_num}    = $page_num;
        $c->stash->{per_page}    = $per_page;
        $c->stash->{by}          = $orderby;
        $c->stash->{direction}   = $orderdirection || 'asc';
        $c->stash->{items}       = $items_ref;
        $c->stash->{field_names} = $field_names;
        $c->stash->{pages_count} = ceil( $count / $per_page );
    }
    else {
        $c->response->status($status);
        $c->stash->{status_msg}   = $result;
        $c->stash->{current_view} = 'JSON';
    }
}

sub bad_request : Private {
    my ($self,$c) = @_;
    $c->stash->{current_view} = 'JSON';
    $c->response->status(HTTP_BAD_REQUEST);
    $c->stash->{status_msg} ||= "";
    $c->detach();
}

sub add_fake_profile_data {
    my ($self, $c) = @_;
    $c->stash(
        logo        => $Config{'general'}{'logo'},
        username    => 'mcrispin',
        last_port   => '4097',
        last_vlan   => '102',
        last_ssid   => 'PacketFence-Secure',
        last_switch => '10.0.0.4',
        dhcp_fingerprint      => '1,28,2,3,15,6,119,12,44,47,26,121,42',
        last_connection_type  => 'Wireless-802.11-EAP',
        list_help_info        => [{ name => $c->loc('IP'), value => '10.0.0.123' },
                               { name => $c->loc('MAC'), value => 'c8:bc:c8:ce:65:e1' }]
    );

}

=head2 getForm

=cut

sub getForm {
    my ($self, $c, @args) = @_;
    unless (@args || (exists $c->stash->{current_form} && defined $c->stash->{current_form} )) {
        if (exists $c->action->{form} && defined (my $form = $c->action->{form})) {
            push @args,$form;
        }
    }
    return $c->form(@args);
}

=head2 getModel

=cut

sub getModel {
    my ($self, $c, @args) = @_;
    unless (@args) {
        if (exists $c->action->{model} && defined (my $model = $c->action->{model})) {
            push @args,$model;
        }
    }
    return $c->model(@args);
}


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

