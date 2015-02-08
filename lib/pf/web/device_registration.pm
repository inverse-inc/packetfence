package pf::web::device_registration;

=head1 NAME

pf::web::device

=cut

=head1 DESCRIPTION

Library for the device registration page

=cut

use strict;
use warnings;

use HTML::Entities;
use Readonly;

use pf::config;
use pf::enforcement qw(reevaluate_access);
use pf::node qw(node_register is_max_reg_nodes_reached);
use pf::util;
use pf::web;
use pf::web::custom;    # called last to allow redefinitions

use pf::authentication;
use pf::Authentication::constants;
use List::MoreUtils qw(any);

Readonly our $DEVICE_LOGIN_TEMPLATE   => 'device-login.html';
Readonly our $DEVICE_LANDING_TEMPLATE => 'device-landing.html';
Readonly our $DEVICE_REGISTRATION_TEMPLATE => 'device-registration.html';
Readonly our @DEVICE_OUI => _load_file_into_array($allowed_device_oui_file);
Readonly our @DEVICE_TYPES => _load_file_into_array($allowed_device_types_file);

=head1 SUBROUTINES

=over

=cut


=item _load_file_into_array

Loads each line of file into array
Trimming spaces and removing shell style comments from each line

=cut

sub _load_file_into_array {
    my ($file_name) = @_;
    my @items;
    if(-r $file_name) {
        local *FILE;
        open(FILE,$file_name);
        @items =
            grep {$_}
            map {
                #Getting rid of newlines, comments and trimming spaces
                chomp; s/#.*$//; s/^\s+//; s/\s+$//;
                $_;
            } <FILE>;
        close(FILE);
    }
    return @items;
}

=item is_allowed

Validate if mac address is an allowed device mac

=cut

sub is_allowed {
    my ($mac) = @_;
    return 1 unless @DEVICE_OUI;
    $mac =~ s/O/0/i;
    $mac = clean_mac($mac);
    return any { $mac =~ /^\Q$_\E/i } @DEVICE_OUI;
}

=back

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
