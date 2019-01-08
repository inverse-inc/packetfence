package pf::I18N;

=head1 NAME

pf::I18N -

=head1 DESCRIPTION

pf::I18N

=cut

use strict;
use warnings;
use POSIX;
use Locale::gettext qw(bindtextdomain textdomain bind_textdomain_codeset);
use pf::file_paths qw($conf_dir);

sub setup_text_domain {
    delete $ENV{'LANGUAGE'}; # Make sure $LANGUAGE is empty otherwise it will override LC_MESSAGES
    bindtextdomain("packetfence", "$conf_dir/locale");
    bind_textdomain_codeset("packetfence", "utf-8");
    textdomain("packetfence");
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
