package pf::I18N::pfappserver;

=head1 NAME

pf::I18N::pfappserver -

=cut

=head1 DESCRIPTION

pf::I18N::pfappserver

=cut

use strict;
use warnings;
use utf8;
use pf::file_paths qw($install_dir);

our $PATH;

BEGIN {
    $PATH = "$install_dir/html/pfappserver/lib/pfappserver/I18N/";
}

use Locale::Maketext::Simple (
    class => 'pf::I18N::pfappserver',
    Subclass  => 'I18N',
    Path => $PATH,
    Export => '_loc', 
    Decode => 1,
);
use I18N::LangTags ();
use I18N::LangTags::Detect;
use I18N::LangTags::List;

sub get_handle {
    my ($self, @args) = @_;
    pf::I18N::pfappserver::I18N->get_handle(@args);;
}

sub localize {
    my ($self, $text, $args) = @_;
    if (ref $args eq 'ARRAY') {
        return _loc($text, @$args);
    }
    return _loc($text);
}

sub languages_from_http_header {
    my ($header) = @_;
    return [
        I18N::LangTags::implicate_supers(
            I18N::LangTags::Detect->http_accept_langs( $header )
        ),
        'i-default'
    ];
}

sub languages_list {
    my %languages_list;
    if ( opendir my $langdir, $PATH ) {
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

Copyright (C) 2005-2018 Inverse inc.

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
