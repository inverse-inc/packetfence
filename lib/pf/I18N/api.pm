package pf::I18N::api;

=head1 NAME

pf::I18N::api -

=cut

=head1 DESCRIPTION

pf::I18N::api

=cut

use strict;
use warnings;
use utf8;
use pf::file_paths qw($api_i18n_dir);

use base 'Locale::Maketext';

use Locale::Maketext::Lexicon {
   'i-default' => [ 'Auto' ],
   '*' => [
        Gettext => "$api_i18n_dir/*.[pm]o",
        Gettext => "$api_i18n_dir/*.local.[pm]o"
    ],
   _decode => 1,
};

our %Lexicon;

*Lexicon = \%pf::I18N::api::i_default::Lexicon;

our $default_lh = __PACKAGE__->get_handle;

use I18N::LangTags ();
use I18N::LangTags::Detect;
use I18N::LangTags::List;

=head2 fallback_languages

The fallback languages

=cut

sub fallback_languages {
    ('i-default')
}

=head2 get_handle

get the I18N handle

=cut

sub get_handle {
    my ($self, @lang) = @_;
    return $self->SUPER::get_handle(@lang, $self->fallback_languages);
}

=head2 localize

localize using the default handle

=cut

sub localize {
    my ($self, $text, $args) = @_;
    if (ref $text eq 'ARRAY') {
        my $msg = shift(@$text);
        return _loc($msg, @$text)
    }
    if (ref $args eq 'ARRAY') {
        return _loc($text, @$args);
    }
    return _loc($text);
}

sub _loc {
    $default_lh->maketext(@_)
}

=head2 languages_from_http_header

Get languages from the http headers

=cut

sub languages_from_http_header {
    my ($self, $header) = @_;
    return [
        I18N::LangTags::implicate_supers(
            I18N::LangTags::Detect->http_accept_langs( $header )
        ),
        $self->fallback_languages,
    ];
}

=head2 languages_list

The list of languages that is installed

=cut

sub languages_list {
    my %languages_list;
    if ( opendir my $langdir, $api_i18n_dir ) {
        foreach my $entry ( readdir $langdir ) {
            next unless $entry =~ m/\A (\w+)\.(?:pm|po|mo) \z/xms;
            my $langtag = $1;
            next if $langtag eq "i_default";
            my $language_tag = $langtag;
            $language_tag =~ s/_/-/g;
            $languages_list{$langtag} =
              I18N::LangTags::List::name($language_tag);
        }
        closedir $langdir;
    }
    return \%languages_list;
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
