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

our %ALLOWED_ATTRIBUTES = (
    Public => 1,
    Fork => 1,
);

our %SHOULD_FORK;
our %EXPORTED_API;

sub MODIFY_CODE_ATTRIBUTES {
    my ($class, $code, @attrs) = @_;
    my (@bad, @good);
    foreach my $attr (@attrs) {
        if (exists $ALLOWED_ATTRIBUTES{$attr} ) {
            push @good, $attr;
        } else {
            push @bad, $attr;
        }
    }
    _updateExportedApi($code,@good) unless @bad;
    return @bad;
}

sub _updateExportedApi {
    my ($code, @attrs) = @_;
    my %attrs;
    @attrs{@attrs} = ();
    my $ref_add = Scalar::Util::refaddr($code);
    if (exists $attrs{Public}) {
        $EXPORTED_API{$ref_add} = $code;
        Scalar::Util::weaken($EXPORTED_API{$ref_add});
    }
    if (exists $attrs{Fork}) {
        $SHOULD_FORK{$ref_add} = $code;
        Scalar::Util::weaken($SHOULD_FORK{$ref_add});
    }
}

sub isPublic {
    my ($class, $method) = @_;
    my $code = $class->can($method);
    return $code
      if $code && exists $EXPORTED_API{Scalar::Util::refaddr($code)};
    return;
}

sub shouldFork {
    my ($class, $method) = @_;
    my $code = $class->can($method);
    return $code && exists $SHOULD_FORK{Scalar::Util::refaddr($code)};
}

sub CLONE {
    # fix-up all object ids in the new thread
    my @code_refs = grep {defined} values %EXPORTED_API;
    %EXPORTED_API = ();
    _updateExportedApi($_, 'Public') foreach @code_refs;
    %SHOULD_FORK = ();
    @code_refs = grep {defined} values %EXPORTED_API;
    _updateExportedApi($_, 'Fork') foreach @code_refs;
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

