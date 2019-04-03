package pf::task::domain;

=head1 NAME

pf::task::domain

=cut

=head1 DESCRIPTION

Task to perform long-running AD domain operations (join, unjoin, rejoin)

=cut

use strict;
use warnings;
use base 'pf::task';
use pf::domain;
use pf::log;
use pf::config qw(%ConfigDomain);
use pf::constants::pfqueue qw($STATUS_FAILED);
use pf::ConfigStore::Domain;

our %OP_MAP = (
    join => \&pf::domain::join_domain,
    unjoin => \&pf::domain::unjoin_domain,
    rejoin => \&pf::domain::rejoin_domain,
);

=head2 doTask

Log to pfqueue.log

=cut

sub doTask {
    my ($self, $args) = @_;
    my $logger = get_logger;

    my $op = $args->{operation};
    my $domain = $args->{domain};

    unless(exists($OP_MAP{$op})) {
        my $msg = "Invalid operation $op for domain";
        $logger->error($msg);
        $self->status_updater->set_status_msg($msg);
        $self->status_updater->set_status($STATUS_FAILED);
        $self->status_updater->finalize();
        return;
    }

    unless(exists($ConfigDomain{$domain})) {
        my $msg = "Invalid domain $domain for domain task";
        $logger->error($msg);
        $self->status_updater->set_status_msg($msg);
        $self->status_updater->set_status($STATUS_FAILED);
        $self->status_updater->finalize();
        return;
    }

    my $result = $OP_MAP{$op}->($domain);
    $self->reset_credentials($domain);
    return $result;
}

=head2 reset_credentials

Reset the domain credentials

=cut

sub reset_credentials {
    my ($self, $domain) = @_;
    my $model = pf::ConfigStore::Domain->new;
    my ($status,$result) = $model->update($domain, { bind_dn => undef, bind_pass => undef } );
    $model->commit();
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

