package pf::UnifiedApi::Controller::Config::Domains;

=head1 NAME

pf::UnifiedApi::Controller::Config::Domains -

=cut

=head1 DESCRIPTION

pf::UnifiedApi::Controller::Config::Domains

=cut

use strict;
use warnings;

use Mojo::Base qw(pf::UnifiedApi::Controller::Config);

has 'config_store_class' => 'pf::ConfigStore::Domain';
has 'form_class' => 'pfappserver::Form::Config::Domain';
has 'primary_key' => 'domain_id';

use pf::ConfigStore::Domain;
use pfappserver::Form::Config::Domain;
use pf::domain;
use pf::pfqueue::producer::redis;

=head2 test_join

Test if a domain is properly joined

=cut

sub test_join {
    my ($self) = @_;
    my $domain_id = $self->stash('domain_id');
    my ($status, $msg) = pf::domain::test_join($domain_id);
    $self->render(json => {message => $msg}, status => $status == 0 ? 200 : 422);
}

=head2 handle_domain_operation

Post a long running operation to the queue and render the task ID to follow its status

=cut

sub handle_domain_operation {
    my ($self, $op) = @_;
    my $client = pf::pfqueue::producer::redis->new();
    my $task_id = $client->submit("general", domain => {operation => $op, domain => $self->stash('domain_id')}, undef, status_update => 1);
    $self->render(
        json => {
            "task_id" => $task_id,
        },
        status => 200,
    );
}

=head2 join

Join to the domain via the queue

=cut

sub join {
    my ($self) = @_;
    $self->handle_domain_operation("join");
}

=head2 unjoin

Unjoin to the domain via the queue

=cut

sub unjoin {
    my ($self) = @_;
    $self->handle_domain_operation("unjoin");
}

=head2 rejoin

Rejoin to the domain via the queue

=cut

sub rejoin {
    my ($self) = @_;
    $self->handle_domain_operation("rejoin");
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
