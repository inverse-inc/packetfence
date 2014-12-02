package pfappserver::Controller::Configuration;

=head1 NAME

pfappserver::Controller::Configuration

=head1 DESCRIPTION

Place all customization for Controller::Configuration here

=cut

use Moose;
use namespace::autoclean;
use POSIX;
use URI::Escape::XS;
use Log::Log4perl qw(get_logger);

use pf::os;
use pf::util qw(load_oui download_oui);
# imported only for the $TIME_MODIFIER_RE regex. Ideally shouldn't be
# imported but it's better than duplicating regex all over the place.
use pf::config;
use pf::admin_roles;
use pfappserver::Form::Config::Pf;

BEGIN {extends 'pfappserver::Base::Controller'; }

=head1 METHODS

=cut

=head2 _process_section

=cut

our %ALLOWED_SECTIONS = (
    general => undef,
    network => undef,
    trapping => undef,
    registration => undef,
    guests_self_registration => undef,
    guests_admin_registration => undef,
    billing => undef,
    alerting => undef,
    scan => undef,
    maintenance => undef,
    expire => undef,
    services => undef,
    vlan => undef,
    inline => undef,
    servicewatch => undef,
    captive_portal => undef,
    advanced => undef,
    provisioning => undef,
    webservices => undef,
    active_active => undef,
);


=head2 index

=cut

sub index :Path :Args(0) { }


=head2 section

BEGIN { extends 'pfappserver::PacketFence::Controller::Configuration'; }

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


__PACKAGE__->meta->make_immutable;

1;
