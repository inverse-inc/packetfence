package pf::UnifiedApi::Controller::Config::SwitchGroups;

=head1 NAME

pf::UnifiedApi::Controller::Config::SwitchGroups - 

=cut

=head1 DESCRIPTION

pf::UnifiedApi::Controller::Config::SwitchGroups



=cut

use strict;
use warnings;

use Mojo::Base qw(pf::UnifiedApi::Controller::Config);
use Role::Tiny::With;
with 'pf::UnifiedApi::Controller::Config::SwitchRole';

has 'config_store_class' => 'pf::ConfigStore::SwitchGroup';
has 'form_class' => 'pfappserver::Form::Config::SwitchGroup';
has 'primary_key' => 'switch_group_id';

use pf::ConfigStore::SwitchGroup;
use pfappserver::Form::Config::SwitchGroup;
use pfappserver::Form::Config::Switch;

=head2 members

members

=cut

sub members {
    my ($self) = @_;
    my $cs     = pf::ConfigStore::Switch->new;
    my $params = $self->req->query_params->to_hash;
    my %search_info = (
        raw => 'true',
        (
            map {
                exists $params->{$_}
                ? ($_ => isenabled($params->{$_}))
                : ()
            } qw(raw)
        )
    );

    my @items = $cs->membersOfGroup($self->id);
    unless ($search_info{raw}) {
        my $form   = pfappserver::Form::Config::Switch->new;
        @items = map { $self->cleanup_item($_, $form) } @items;
    }
    return $self->render( json => { items => \@items } );
}

sub form_parameters {
    [
        inactive => [ qw(always_trigger) ],
    ];
}

=head2 fields_to_mask

fields_to_mask

=cut

sub fields_to_mask { qw(radiusSecret cliPwd wsPwd) }

=head1 AUTHOR

Inverse inc. <info@inverse.ca>

=head1 COPYRIGHT

Copyright (C) 2005-2024 Inverse inc.

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
