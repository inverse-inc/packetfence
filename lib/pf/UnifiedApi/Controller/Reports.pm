package pf::UnifiedApi::Controller::Reports;

=head1 NAME

pf::UnifiedApi::Controller::Reports -

=cut

=head1 DESCRIPTION

pf::UnifiedApi::Controller::Reports

=cut

use strict;
use warnings;
use Mojo::Base 'pf::UnifiedApi::Controller::Crud';
use pf::pfcmd::report;

sub os {
    my ($self) = @_;
    $self->render(json => { items => [report_os()]});
}

sub os_active {
    my ($self) = @_;
    $self->render(json => { items => [report_os_active()]});
}

sub os_all {
    my ($self) = @_;
    $self->render(json => { items => [report_os_all()]});
}

sub osclass_all {
    my ($self) = @_;
    $self->render(json => { items => [report_osclass_all()]});
}

sub osclass_active {
    my ($self) = @_;
    $self->render(json => { items => [report_osclass_active()]});
}

sub inactive_all {
    my ($self) = @_;
    $self->render(json => { items => [report_inactive_all()]});
}

sub active_all {
    my ($self) = @_;
    $self->render(json => { items => [report_active_all()]});
}

sub unregistered_all {
    my ($self) = @_;
    $self->render(json => { items => [report_unregistered_all()]});
}

sub unregistered_active {
    my ($self) = @_;
    $self->render(json => { items => [report_unregistered_active()]});
}

sub registered_all {
    my ($self) = @_;
    $self->render(json => { items => [report_registered_all()]});
}

sub registered_active {
    my ($self) = @_;
    $self->render(json => { items => [report_registered_active()]});
}

sub unknownprints_all {
    my ($self) = @_;
    $self->render(json => { items => [report_unknownprints_all()]});
}

sub unknownprints_active {
    my ($self) = @_;
    $self->render(json => { items => [report_unknownprints_active()]});
}

sub statics_all {
    my ($self) = @_;
    $self->render(json => { items => [report_statics_all()]});
}

sub statics_active {
    my ($self) = @_;
    $self->render(json => { items => [report_statics_active()]});
}

sub openviolations_all {
    my ($self) = @_;
    $self->render(json => { items => [report_openviolations_all()]});
}

sub openviolations_active {
    my ($self) = @_;
    $self->render(json => { items => [report_openviolations_active()]});
}

sub connectiontype {
    my ($self) = @_;
    $self->render(json => { items => [report_connectiontype()]});
}

sub connectiontype_all {
    my ($self) = @_;
    $self->render(json => { items => [report_connectiontype_all()]});
}

sub connectiontype_active {
    my ($self) = @_;
    $self->render(json => { items => [report_connectiontype_active()]});
}

sub connectiontypereg_all {
    my ($self) = @_;
    $self->render(json => { items => [report_connectiontypereg_all()]});
}

sub connectiontypereg_active {
    my ($self) = @_;
    $self->render(json => { items => [report_connectiontypereg_active()]});
}

sub ssid {
    my ($self) = @_;
    $self->render(json => { items => [report_ssid()]});
}

sub ssid_all {
    my ($self) = @_;
    $self->render(json => { items => [report_ssid_all()]});
}

sub ssid_active {
    my ($self) = @_;
    $self->render(json => { items => [report_ssid_active()]});
}

sub osclassbandwidth {
    my ($self) = @_;
    $self->render(json => { items => [report_osclassbandwidth()]});
}

sub osclassbandwidth_all {
    my ($self) = @_;
    $self->render(json => { items => [report_osclassbandwidth_all()]});
}

sub nodebandwidth {
    my ($self) = @_;
    $self->render(json => { items => [report_nodebandwidth()]});
}

sub nodebandwidth_all {
    my ($self) = @_;
    $self->render(json => { items => [report_nodebandwidth_all()]});
}

sub topsponsor_all {
    my ($self) = @_;
    $self->render(json => { items => [report_topsponsor_all()]});
}

=head1 AUTHOR

Inverse inc. <info@inverse.ca>

=head1 COPYRIGHT

Copyright (C) 2005-2017 Inverse inc.

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

