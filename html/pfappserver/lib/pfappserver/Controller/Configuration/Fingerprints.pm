package pfappserver::Controller::Configuration::Fingerprints;

=head1 NAME

pfappserver::Controller::Fingerprints - Catalyst Controller

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
use pfappserver::Form::Config::Pf;

BEGIN {extends 'Catalyst::Controller'; }

=head1 METHODS

=cut

=head2 auto

Allow only authenticated users

=cut

sub auto :Private {
    my ($self, $c) = @_;

    unless ($c->user_exists()) {
        $c->response->status(HTTP_UNAUTHORIZED);
        $c->response->location($c->req->referer);
        $c->stash->{template} = 'admin/unauthorized.tt';
        $c->detach();
        return 0;
    }

    return 1;
}

=head2 _format_section

=cut

sub _format_section :Private {
    my ($self, $entries_ref) = @_;

    for (my $i = 0; $i < scalar @{$entries_ref}; $i++) {
        my $entry_ref = $entries_ref->[$i];

        # Try to be smart. Description that refers to a comma-delimited list must be bigger.
        if ($entry_ref->{type} eq "text" && $entry_ref->{description} =~ m/comma-delimite/i) {
            $entry_ref->{type} = 'text-large';
        }

        # Value should always be defined for toggles (checkbox and select)
        elsif ($entry_ref->{type} eq "toggle") {
            $entry_ref->{value} = $entry_ref->{default_value} unless ($entry_ref->{value});
        }

        elsif ($entry_ref->{type} eq "date") {
            my $time = str2time($entry_ref->{value} || $entry_ref->{default_value});
            # Match date format of Form::Widget::Theme::Pf
            $entry_ref->{value} = POSIX::strftime("%Y-%m-%d", localtime($time));
        }

        # Limited formatting from text to html
        $entry_ref->{description} =~ s/</&lt;/g; # convert < to HTML entity
        $entry_ref->{description} =~ s/>/&gt;/g; # convert > to HTML entity
        $entry_ref->{description} =~ s/(\S*(&lt;|&gt;)\S*)\b/<code>$1<\/code>/g; # enclose strings that contain < or >
        $entry_ref->{description} =~ s/(\S+\.(html|tt|pm|pl|txt))\b(?!<\/code>)/<code>$1<\/code>/g; # enclose strings that ends with .html, .tt, etc
        $entry_ref->{description} =~ s/^ \* (.+?)$/<li>$1<\/li>/mg; # create list elements for lines beginning with " * "
        $entry_ref->{description} =~ s/(<li>.*<\/li>)/<ul>$1<\/ul>/s; # create lists from preceding substitution
        $entry_ref->{description} =~ s/\"([^\"]+)\"/<i>$1<\/i>/mg; # enclose strings surrounded by double quotes
        $entry_ref->{description} =~ s/(https?:\/\/\S+)/<a href="$1">$1<\/a>/g;
    }
}

=head2 update

=cut
sub update : Local : Args(0) {
    my ( $self, $c ) = @_;
    my ( $status, $version_msg, $total ) =
        update_dhcp_fingerprints_conf();
    $c->stash->{status_message} =
        "DHCP fingerprints updated via $dhcp_fingerprints_url to $version_msg\n"
        . "$total DHCP fingerprints reloaded\n";
}

=head2 upload

=cut
sub upload : Local : Args(0) {
    my ( $self, $c ) = @_;
    require pf::pfcmd::report;
    import pf::pfcmd::report qw(report_unknownprints_all);
    my $content = join(
        "\n",
        (   map {
                join(
                    ":",
                    @{$_}{
                        qw(dhcp_fingerprint vendor computername user_agent)
                        }
                    )
                } report_unknownprints_all()
        ),
        ""
    );
    if ($content) {
        require LWP::UserAgent;
        my $browser  = LWP::UserAgent->new;
        my $response = $browser->post(
            'http://www.packetfence.org/fingerprintsv2.php?ref='
                . uri_escape($c->uri_for($c->action->name)),
            { fingerprints => $content }
        );
    }
}

=head2 index

=cut

sub index : Path : Args(0) {
    my ( $self, $c ) = @_;
    my $action = $c->request->params->{'action'} || "";
    if ( $action eq 'update' ) {
        my ( $status, $version_msg, $total ) =
            update_dhcp_fingerprints_conf();
        $c->stash->{status_message} =
            "DHCP fingerprints updated via $dhcp_fingerprints_url to $version_msg\n"
            . "$total DHCP fingerprints reloaded\n";
    }
    elsif ( $action eq 'upload' ) {
        require pf::pfcmd::report;
        import pf::pfcmd::report qw(report_unknownprints_all);
        my $content = join(
            "\n",
            (   map {
                    join(
                        ":",
                        @{$_}{
                            qw(dhcp_fingerprint vendor computername user_agent)
                            }
                        )
                    } report_unknownprints_all()
            ),
            ""
        );
        if ($content) {
            require LWP::UserAgent;
            my $browser  = LWP::UserAgent->new;
            my $response = $browser->post(
                'http://www.packetfence.org/fingerprintsv2.php?ref='
                    . uri_escape($c->uri_for($c->action->name)),
                { fingerprints => $content }
            );
        }
    }
    $self->_list_items( $c, 'OS' );
}

=head2 useragents

=cut

sub _list_items {
    my ( $self, $c, $model_name ) = @_;
    my ( $filter, $orderby, $orderdirection, $status, $result, $items_ref );
    my $model       = $c->model($model_name);
    my $field_names = $model->field_names();
    my $page_num    = $c->request->params->{'page_num'} || 1;
    my $per_page    = $c->request->params->{'per_page'} || 25;
    my $limit_clause =
        "LIMIT " . ( ( $page_num - 1 ) * $per_page ) . "," . $per_page;
    my %params = ( limit => $limit_clause );

    if ( exists( $c->req->params->{'filter'} ) ) {
        $filter = $c->req->params->{'filter'};
        $params{'where'} = { type => 'any', like => $filter };
        $c->stash->{filter} = $filter;
    }
    if ( exists( $c->request->params->{'by'} ) ) {
        $orderby = $c->request->params->{'by'};
        if ( grep { $_ eq $orderby } (@$field_names) ) {
            $orderdirection = $c->request->params->{'direction'};
            unless ( grep { $_ eq $orderdirection } ( 'asc', 'desc' ) ) {
                $orderdirection = 'asc';
            }
            $params{'orderby'}     = "ORDER BY $orderby $orderdirection";
            $c->stash->{by}        = $orderby;
            $c->stash->{direction} = $orderdirection;
        }
    }
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
        $c->stash->{by}          = $orderby || $field_names->[0];
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


sub macaddress : Local {
    my ( $self, $c ) = @_;
    my $action = $c->request->params->{'action'} || "";
    if ( $action eq 'update' ) {
        download_oui();
        load_oui(1);
    }
    $self->_list_items( $c, 'MacAddress' );
}

=head1 AUTHOR
=head2 roles

=cut

sub roles :Local {
    my ( $self, $c ) = @_;

    $c->stash->{template} = 'configuration/roles.tt';

    my ($status, $result) = $c->model('Roles')->list();
    if (is_success($status)) {
        $c->stash->{roles} = $result;
    }
    else {
        $c->stash->{error} = $result;
    }
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
