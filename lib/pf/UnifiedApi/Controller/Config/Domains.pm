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
use pf::error qw(is_error);
use pf::pfqueue::producer::redis;

=head2 test_join

Test if a domain is properly joined

=cut

sub test_join {
    my ($self) = @_;
    my ($status, $msg) = pf::domain::test_join($self->id);
    chomp($msg);
    $self->render(json => {message => $msg}, status => $status == 0 ? 200 : 422);
}

=head2 handle_domain_operation

Post a long running operation to the queue and render the task ID to follow its status

=cut

sub handle_domain_operation {
    my ($self, $op) = @_;
    my ($status, $json) = $self->parse_json;
    if (is_error($status)) {
        return $self->render(status => $status, json => $json);
    }

    ($status, my $data) = $self->validate_input($json);
    if (is_error($status)) {
        return $self->render(status => $status, json => $data);
    }

    my $client = pf::pfqueue::producer::redis->new();
    my $task_id = $client->submit("general", domain => {%$data, operation => $op, domain => $self->id}, undef, status_update => 1);
    $self->render(
        json => {
            "task_id" => $task_id,
        },
        status => 202,
    );
}

=head2 validate_input

validate_input

=cut

sub validate_input {
    my ($sel, $data) = @_;

    my $bind_dn = $data->{username};
    my $bind_pass = $data->{password};
    my @errors;
    if (!defined $bind_dn || length($bind_dn) == 0) {
        push @errors, {message => 'field username is required', field => 'username'},
    }

    if (!defined $bind_pass || length($bind_pass) == 0) {
        push @errors, {message => 'field password is required', field => 'password'},
    }

    if (@errors) {
        return 422, { message => 'username and or password missing' , errors => \@errors};
    }

    return 200, { bind_dn => $bind_dn, bind_pass => $bind_pass };
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
