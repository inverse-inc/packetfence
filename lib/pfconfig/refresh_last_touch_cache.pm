package pfconfig::refresh_last_touch_cache;

=head1 NAME

pfconfig::refresh_last_touch_cache

=cut

=head1 DESCRIPTION

pfconfig::refresh_last_touch_cache

Utilities function to refresh the last touch cache

=cut


use pfconfig::cached;
use pfconfig::cached_scalar;

BEGIN {
    use Exporter ();
    our ( @ISA, @EXPORT );
    @ISA = qw(Exporter);
    # Categorized by feature, pay attention when modifying
    @EXPORT = qw(
        refresh_last_touch_cache
    );
}

sub refresh_last_touch_cache {
    tie my $dummy, 'pfconfig::cached_scalar', 'resource::fqdn';
    tied($dummy)->FETCH();
}

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

# vim: set shiftwidth=4:
# vim: set expandtab:
# vim: set backspace=indent,eol,start:

