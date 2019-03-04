package pf::UnifiedApi::Controller::Translations;

=head1 NAME

pf::UnifiedApi::Controller::Translations -

=cut

=head1 DESCRIPTION

pf::UnifiedApi::Controller::Translations

=cut

use strict;
use warnings;
use Mojo::Base 'pf::UnifiedApi::Controller::RestRoute';
use pf::I18N::pfappserver;

our $languages_list = pf::I18N::pfappserver->languages_list;

sub list {
    my ($self) = @_;
    my @items = (
        {
            lang    => 'i_default',
            lexicon => \%pf::I18N::pfappserver::Lexicon,
        },
    );
    for my $lang (keys(%$languages_list)) {
        push @items, {
            lang => $lang,
            lexicon => $self->lexicon($lang),
        };
    }

    return $self->render(status => 200, json => {items => \@items});
}

sub resource {
    my ($self) = @_;
    my $translation_id = $self->stash('translation_id');
    return exists $languages_list->{$translation_id};
}

sub get {
    my ($self) = @_;
    my $lang = $self->stash('translation_id');
    my $lexicon = $self->lexicon($lang);
    return $self->render(
        status => 200,
        json => {
            item => {
                lang => $lang,
                lexicon => $lexicon,
            }
        }
    );
}

sub lexicon {
    my ($self, $lang) = @_;
    no strict qw(refs);
    my $lexicon = "pf::I18N::pfappserver::${lang}::Lexicon";
    my $ref = *{$lexicon};
    return \%{$ref};
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
