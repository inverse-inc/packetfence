package pf::UnifiedApi::Controller::I18N;

=head1 NAME

pf::UnifiedApi::Controller::I18N -

=cut

=head1 DESCRIPTION

pf::UnifiedApi::Controller::I18N

=cut

use strict;
use warnings;
use Mojo::Base 'pf::UnifiedApi::Controller';
use pf::I18N::pfappserver;

sub list {
    my ($self) = @_;
    my $languages_list = pf::I18N::pfappserver->languages_list;
    my %list;
    for my $lang (keys(%$languages_list), 'i_default') {
        no strict qw(refs);
        my $lexicon = "pf::I18N::pfappserver::${lang}::Lexicon";
        my $ref = *{$lexicon};
        $list{$lang} = \%{$ref};
    }
    return $self->render(status => 200, json => \%list);
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
