package captiveportal::DynamicRouting::Actions;

=head1 NAME

captiveportal::DynamicRouting::Actions

=head1 DESCRIPTION

Actions for Dynamic Routing

=cut

use strict;
use warnings;
use base qw(Exporter);
our @EXPORT = qw(
    %AUTHENTICATION_ACTIONS
);

use pf::authentication;
use pf::Authentication::constants;

our %AUTHENTICATION_ACTIONS = (
    set_role => sub { $_[0]->new_node_info->{category} = $_[1]; },
    set_unregdate => sub { $_[0]->new_node_info->{unregdate} = $_[1] },
    set_access_duration => sub { $_[0]->new_node_info->{unregdate} = access_duration($_[1]) },
    unregdate_from_source => sub { $_[0]->new_node_info->{unregdate} = pf::authentication::match($_[0]->source->id, $_[0]->auth_source_params, $Actions::SET_UNREG_DATE); },
    role_from_source => sub { $_[0]->new_node_info->{category} = pf::authentication::match($_[0]->source->id, $_[0]->auth_source_params, $Actions::SET_ROLE); },
);

=head1 AUTHOR

Inverse inc. <info@inverse.ca>

=head1 COPYRIGHT

Copyright (C) 2005-2016 Inverse inc.

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

