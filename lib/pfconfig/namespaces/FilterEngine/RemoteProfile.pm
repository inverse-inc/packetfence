package pfconfig::namespaces::FilterEngine::RemoteProfile;

=head1 NAME

pfconfig::namespaces::FilterEngine::RemoteProfile

=cut

=head1 DESCRIPTION

pfconfig::namespaces::FilterEngine::RemoteProfile

=cut

use strict;
use warnings;
use pf::log;
use pfconfig::namespaces::config;
use pfconfig::namespaces::config::RemoteProfiles;
use pf::config::builder::filter_engine::remote_profile;
use pf::access_filter::remote_profile;

use base 'pfconfig::namespaces::FilterEngine::AccessScopes';

sub parentConfig {
    my ($self) = @_;
    return pfconfig::namespaces::config::RemoteProfiles->new($self->{cache});
}

sub build {
    my ($self) = @_;
    my $scopes = $self->SUPER::build();
    return pf::access_filter::remote_profile->new($scopes);
}

sub builder {
    return pf::config::builder::filter_engine::remote_profile->new; 
}

=head1 AUTHOR

Inverse inc. <info@inverse.ca>

=head1 COPYRIGHT

Copyright (C) 2005-2020 Inverse inc.

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

