package pfappserver::Model::Config::Violations;

=head1 NAME

pfappserver::Model::Config::Violations

=cut

=head1 DESCRIPTION

pfappserver::Model::Config::Violations

=cut

use Moose;
use namespace::autoclean;

use pf::config::cached;
use pf::config;
use pf::violation_config;
use HTTP::Status qw(:constants is_error is_success);
use pf::ConfigStore::Violations;

extends 'pfappserver::Base::Model::Config';

sub _buildConfigStore { pf::ConfigStore::Violations->new }

=head1 Methods

=head2 availableTemplates

Return the list of available remediation templates

=cut

sub availableTemplates {
    opendir(DIR, $CAPTIVE_PORTAL{TEMPLATE_DIR} . '/violations');
    my @templates = grep { /^[^\.]+\.html$/ } readdir(DIR);
    s/\.html// for @templates;
    closedir(DIR);

    return \@templates;
}

=head2 listTriggers

=cut

sub listTriggers {
    my ($self) = @_;
    return $self->configStore->listTriggers;
}


=head2 addTrigger

=cut

sub addTrigger {
    my ( $self,$id,$trigger ) = @_;
    my ($status,$status_msg) = $self->hasId($id);
    if(is_success($status)) {
        my $result = $self->configStore->addTrigger($id,$trigger);
        $status_msg = $result == 1  ? "Successfully added trigger to violation" : 'Trigger already included.';
    }
    return ($status,$status_msg);
}

=head2 deleteTrigger

=cut

sub deleteTrigger {
    my ( $self,$id,$trigger ) = @_;
    my ($status,$status_msg) = $self->hasId($id);
    if(is_success($status)) {
        my $result = $self->configStore->deleteTrigger($id,$trigger);
        $status_msg = $result == 1  ? "Successfully deleted trigger from violation" : 'Trigger already excluded.';
    }
    return ($status,$status_msg);
}

=head1 AUTHOR

Inverse inc. <info@inverse.ca>

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

