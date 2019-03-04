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
use Sub::Util();
use List::MoreUtils qw(any);

our %ALLOWED_ATTRIBUTES = (
    Public => 1,
    Fork => 1,
    AllowedAsAction => 1,
    ActionParams => 1,
    RestPath => 1,
);

our $ATTRIBUTE_WITH_PARAMS = qr/([a-zA-Z0-9_]+)\((.*)\)/;


our %TAGS;
our %ALLOWED_ACTIONS;
our %REST_PATHS;

sub MODIFY_CODE_ATTRIBUTES {
    my ($class, $code, @attrs) = @_;
    my (@bad, %extra);
    foreach my $attr (@attrs) {
        if (exists $ALLOWED_ATTRIBUTES{$attr} ) {
            $extra{$attr} = 1;
        }
        elsif ( $attr =~ $ATTRIBUTE_WITH_PARAMS ) {
            if (exists $ALLOWED_ATTRIBUTES{$1} ) {
               $extra{$1} = $2;
            }
            else {
                push @bad, $attr;
            }
        }
        else {
            push @bad, $attr;
        }
    }
    unless(@bad){
        _updateTags($code, \%extra);
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
    Scalar::Util::weaken($REST_PATHS{$rest_path});
}

sub _updateTags {
    my ($code, $attrs) = @_;
    my $ref_add = Scalar::Util::refaddr($code);
    $attrs->{code} = $code;
    Scalar::Util::weaken($attrs->{code});
    if (exists $attrs->{RestPath}) {
       _updateRestPath($code, $attrs->{RestPath});
    }
    $TAGS{$ref_add} = $attrs;
}

sub updateAllowedAsActions {
    for my $info (values %TAGS) {
        if (exists $info->{AllowedAsAction}) {
            $ALLOWED_ACTIONS{Sub::Util::subname($info->{code})} = $info->{AllowedAsAction};
        }
    }
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
    %REST_PATHS = ();
    foreach my $tag_data (@tags) {
        my $code = delete $tag_data->{code};
        _updateTags($code, $tag_data);
    }
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

