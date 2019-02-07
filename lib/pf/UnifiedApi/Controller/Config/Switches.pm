package pf::UnifiedApi::Controller::Config::Switches;

=head1 NAME

pf::UnifiedApi::Controller::Config::Switches - 

=cut

=head1 DESCRIPTION

pf::UnifiedApi::Controller::Config::Switches

=cut

use strict;
use warnings;

use Mojo::Base qw(pf::UnifiedApi::Controller::Config);

has 'config_store_class' => 'pf::ConfigStore::Switch';
has 'form_class' => 'pfappserver::Form::Config::Switch';
has 'primary_key' => 'switch_id';

use pf::ConfigStore::Switch;
use pfappserver::Form::Config::Switch;

=head2 invalidate_cache

invalidate switch cache

=cut

sub invalidate_cache {
    my ($self) = @_;
    my $switch_id = $self->item;
    my $switch = pf::SwitchFactory->instantiate($switch_id);
    unless ( ref($switch) ) {
        return $self->render_error(status => 422, "Cannot instantiate switch $switch");
    }

    $switch->invalidate_distributed_cache();
    return $self->render(status => 200, json => { });
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
