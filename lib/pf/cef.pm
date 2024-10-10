package pf::cef;

=head1 NAME

pf::cef -

=head1 DESCRIPTION

pf::cef

=cut

use strict;
use warnings;
use Moo;
use pf::version;

#CEF:Version|Device Vendor|Device Product|Device Version|Device Event Class ID|Name|Severity|[Extension]

has version => ( default => 0, is => 'ro');

has deviceVendor => (default => 'Inverse', is => 'ro');

has deviceProduct => (default => 'PacketFence', is => 'ro');

has deviceVersion => (default => \&pf::version::version_get_current, is => 'ro');

has deviceEventClassId => ( required => 1, is => 'ro');

has severity => (required => 1, is => 'ro');

sub format_header {
    my ($str) = @_;
    $str =~ s/([\\|])/\\$1/g;
    return $str;
}

sub format_ext {
    my ($str) = @_;
    $str =~ s/([\\=])/\\$1/gm;
    $str =~ s/\n/\\n/gm;
    $str =~ s/\r/\\r/gm;
    return $str;
}

sub message {
    my ($self, $name, $extensions) = @_;
    
    return join(
        "|",
        "CEF:" . $self->version,
        format_header($self->deviceVendor),
        format_header($self->deviceProduct),
        format_header($self->deviceVersion),
        format_header($self->deviceEventClassId),
        format_header($name),
        format_header($self->severity),
        _format_ext($extensions),
    );
}

sub _format_ext {
    my ($ext) = @_;
    my @results;
    while (my ($k,$v) = each %$ext) {
        push @results, "$k=$v";
    }
    if (@results) {
        return join(' ', @results);
    }
    return "";
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
