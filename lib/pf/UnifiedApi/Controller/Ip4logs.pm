package pf::UnifiedApi::Controller::Ip4logs;

=head1 NAME

pf::UnifiedApi::Controller::Ip4logs -

=cut

=head1 DESCRIPTION

pf::UnifiedApi::Controller::Ip4logs

=cut

use strict;
use warnings;
use Mojo::Base 'pf::UnifiedApi::Controller::Crud';
use pf::ip4log;

has dal => 'pf::dal::ip4log';
has url_param_name => 'ip4log_id';
has primary_key => 'ip';

sub open {
    my ($self) = @_;
    my $search = $self->param('search');
    my @iplog = pf::ip4log::list_open($search);
    return $self->render(json => { item => $iplog[0] }) if $iplog[0];
    return $self->render(status => 404, json => { message => $self->status_to_error_msg(404) });
}

sub history {
    my ($self) = @_;
    my $search = $self->param('search');
    my @iplog = pf::ip4log::get_history($search);
    return $self->render(json => { items => \@iplog } ) if scalar @iplog > 0 and defined($iplog[0]);
    return $self->render(json => { items => [] });
}

sub archive {
    my ($self) = @_;
    my $search = $self->param('search');
    my @iplog = pf::ip4log::get_archive($search);
    return $self->render(json => { items => \@iplog } ) if scalar @iplog > 0 and defined($iplog[0]);
    return $self->render(json => { items => [] });
}

sub mac2ip {
    my ($self) = @_;
    my $mac = $self->param('mac');
    return $self->render(json => { ip => pf::ip4log::mac2ip($mac) });
}

sub ip2mac {
    my ($self) = @_;
    my $ip = $self->param('ip');
    return $self->render(json => { mac => pf::ip4log::ip2mac($ip) });
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
