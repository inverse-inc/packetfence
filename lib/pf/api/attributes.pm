package pf::api::attributes;

=head1 NAME

pf::api::attributes helper module for allowing attributes for pf::api

=cut

=head1 DESCRIPTION

pf::api::attributes

=cut

use strict;
use warnings;
use Scalar::Util( );

our %EXPORTED_API;

sub MODIFY_CODE_ATTRIBUTES {
    my ($class, $code, @attrs) = @_;
    my @bad = grep {$_ ne 'Public'} @attrs;
    _updateExportedApi($code) unless @bad;
    return @bad;
}

sub _updateExportedApi {
    my ($code) = @_;
    my $ref_add = Scalar::Util::refaddr($code);
    $EXPORTED_API{$ref_add} = $code;
    Scalar::Util::weaken($EXPORTED_API{$ref_add});
}

sub isPublic {
    my ($class, $method) = @_;
    my $code = $class->can($method);
    return $code
      if $code && exists $EXPORTED_API{Scalar::Util::refaddr($code)};
    return;
}

sub CLONE {
    # fix-up all object ids in the new thread
    my @code_refs = grep {defined} values %EXPORTED_API;
    %EXPORTED_API = ();
    _updateExportedApi($_) foreach @code_refs;
    return;
}

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

