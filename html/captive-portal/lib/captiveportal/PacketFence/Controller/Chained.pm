package captiveportal::PacketFence::Controller::Chained;
=head1 NAME

captiveportal::PacketFence::Controller::Chained Controller for chained auth

=cut

=head1 DESCRIPTION

captiveportal::PacketFence::Controller::Chained

=cut

use Moose;
use namespace::autoclean;
use pf::web::constants;
use URI::Escape::XS qw(uri_escape uri_unescape);
use HTML::Entities;
use pf::enforcement qw(reevaluate_access);
use pf::config;
use pf::log;
use pf::util;
use pf::Portal::Session;
use pf::web;
use pf::node;
use pf::useragent;
use pf::violation;
use pf::class;
use List::Util qw(first);
use POSIX;
use Locale::gettext qw(bindtextdomain textdomain bind_textdomain_codeset);

BEGIN { extends 'captiveportal::Base::Controller'; }


=head2 index

TODO: documention

=cut

sub index : Path Args(0) {
    my ($self) = @_;
    return ;
}

 
=head1 AUTHOR

Inverse inc. <info@inverse.ca>

=head1 COPYRIGHT

Copyright (C) 2005-2014 Inverse inc.

=head1 LICENSE

This program is free software; you can redistribute it and::or
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

