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
use List::MoreUtils qw(any);

our %ALLOWED_ATTRIBUTES = (
    Public => 1,
    Fork => 1,
);

our $REST_PATHS_REGEX = qr/^RestPath\((.*)\)/;

our %TAGS;
our %REST_PATHS;

sub MODIFY_CODE_ATTRIBUTES {
    my ($class, $code, @attrs) = @_;
    my (@bad, @good, $rest_path);
    foreach my $attr (@attrs) {
        if (exists $ALLOWED_ATTRIBUTES{$attr} ) {
            push @good, $attr;
        }
        elsif ( $attr =~ $REST_PATHS_REGEX ){
            $rest_path = $1;
            push @good, $attr;
        }
        else {
            push @bad, $attr;
        }
    }
    unless(@bad){
        _updateTags($code, @good);
        if($rest_path) {
            _updateRestPath($code, $rest_path);
        }
    }
    return @bad;
}

sub restPath {
    my ($class, $path) = @_;
    return undef unless exists $REST_PATHS{$path};
    return $REST_PATHS{$path};
}

sub _updateRestPath {
    my ($code, $rest_path) = @_;
    $REST_PATHS{$rest_path} = $code;
}

sub _updateTags {
    my ($code, @attrs) = @_;
    my %attrs;
    my $ref_add = Scalar::Util::refaddr($code);
    @attrs{@attrs} = ();
    $attrs{code} = $code;
    Scalar::Util::weaken($attrs{code});
    $TAGS{$ref_add} = \%attrs;
}

sub isPublic {
    my ($class, $method) = @_;
    return _hasTag($class, $method, 'Public');
}

sub _hasTag {
    my ($class, $method, $tag) = @_;
    my $code = $class->can($method);
    return unless $code;
    my $ref_addr = Scalar::Util::refaddr($code);
    return unless exists $TAGS{$ref_addr};
    return exists $TAGS{$ref_addr}{$tag};
}

sub shouldFork {
    my ($class, $method) = @_;
    return _hasTag($class, $method, 'Fork');
}

sub CLONE {
    # fix-up all object ids in the new thread
    my @tags = grep {defined} values %TAGS;
    %TAGS = ();
    foreach my $tag_data (@tags) {
        my $code = delete $tag_data->{code};
        _updateTags($code, keys %$tag_data);
    }
    return;
}

=head1 AUTHOR

Inverse inc. <info@inverse.ca>

=head1 COPYRIGHT

Copyright (C) 2005-2016 Inverse inc.

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

