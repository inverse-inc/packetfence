package pfappserver::Base::Controller::Crud::Fingerbank;

=head1 NAME

pfappserver::Base::Controller::Crud::Fingerbank add documentation

=cut

=head1 DESCRIPTION

PortalProfile

=cut

use strict;
use warnings;
use HTTP::Status qw(:constants is_error is_success);
use MooseX::MethodAttributes::Role;
use namespace::autoclean;
use Log::Log4perl qw(get_logger);
use HTML::FormHandler::Params;
use fingerbank::Config;

with 'pfappserver::Base::Controller::Crud::Config' => { -excludes => [qw(list)] };
with 'pfappserver::Base::Controller::Crud::Pagination';
with 'pfappserver::Base::Controller::Crud::Config::Clone';

=head1 METHODS

=head2 action_defaults

Default actions for all fingerbank controllers

=cut

sub action_defaults {
    return (
        object => { Chained => 'scope', PathPart => '', CaptureArgs => 1 },
        # Configure access rights
        view   => { AdminRole => 'FINGERBANK_READ' },
        list   => { AdminRole => 'FINGERBANK_READ', Chained => 'scope' },
        create => { AdminRole => 'FINGERBANK_CREATE' },
        clone  => { AdminRole => 'FINGERBANK_CREATE' },
        update => { AdminRole => 'FINGERBANK_UPDATE' },
        remove => { AdminRole => 'FINGERBANK_DELETE' },
        search => { AdminRole => 'FINGERBANK_READ' },
        index  => { Path => undef, Args => 0 },
    );
}

=head2 scope

Sets the scope of the fingerbank lookup

=cut

sub scope {
    my ($self, $c, $scope) = @_;
    $c->stash->{scope} = $scope;
}

=head2 search

Search fingerbank

=cut

sub search : Chained('scope') : PathPart('search') : Args() {
    my ($self, $c, $pageNum, $perPage) = @_;
    $pageNum ||= 1;
    $perPage ||= 25;
    my $model = $self->getModel($c);
    my $search_fields = $model->search_fields;
    my $value = $c->request->param('value');
    my $query = [ map { $_ => { -like => "%$value%"} } @$search_fields ];
    my ($status, $result) = $model->search(
        $query,
        {   pageNum   => $pageNum,
            perPage   => $perPage,
            by        => 'value',
            direction => 'asc',
        }
    );
    if (is_success($status)) {
        $c->stash(%$result, pageNum => $pageNum, perPage => $perPage, action => 'search', value => $value);
    }
    else {
        $c->stash(
            current_view => 'JSON',
            status_msg   => $result,
        );
        $c->response->status($status);
    }
}

=head2 index

Setup the scope and forwards

=cut

sub index {
    my ($self, $c) = @_;
    $c->stash(
        scope => 'Upstream',
        fingerbank_configured => fingerbank::Config::is_api_key_configured,
        action => 'list',
    );
    $c->forward('list');
}

=head2 get_module_name

Get the module name without pfappserver::Controller:: prefix

=cut

sub get_module_name {
    my ($class) = @_;
    my $module = $class;
    $module =~ s/^pfappserver::Controller::// if $class =~ /^pfappserver::Controller::/;
    $module =~ s/^pfappserver::PacketFence::Controller::// if $class =~ /^pfappserver::PacketFence::Controller::/;
    return $module;
}

=head2 get_form_name

Get the controller's form name

=cut

sub get_form_name {
    return get_module_name(@_);
}

=head2 get_model_name

Get the controller's model name

=cut

sub get_model_name {
    return get_module_name(@_);
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

