package pf::api::local;

=head1 NAME

pf::api::local local client for pf::api

=cut

=head1 DESCRIPTION

pf::api::local

local client for pf::api which calls the api calls directly
To avoid circular dependencies pf::api needs to be included before consuming this module

=cut

use strict;
use warnings;
use Moo;


=head2 call

calls the pf api

=cut

sub call {
    my ($self,$method,@args) = @_;
    return pf::api->$method(@args);
}

=head2 notify

calls the pf api ignoring the return value

=cut

sub notify {
    my ($self,$method,@args) = @_;
    eval {
        pf::api->$method(@args);
    };
    return;
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

