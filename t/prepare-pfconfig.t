#!/usr/bin/perl

=head1 NAME

prepare-pfconfig.t

=cut

=head1 DESCRIPTION

Used to store the sample data into pfconfig before the tests instead of the
data in the normal configuration directory

=cut



BEGIN {
    # log4perl init
    use constant INSTALL_DIR => '/usr/local/pf';
    use lib INSTALL_DIR . "/lib";
    use lib INSTALL_DIR . "/t";
    use setup_test_config;
}

use pfconfig::manager;

pfconfig::manager->new->expire_all;

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

# vim: set shiftwidth=4:
# vim: set expandtab:
# vim: set backspace=indent,eol,start:

