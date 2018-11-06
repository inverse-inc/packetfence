package pfappserver::Form::Field::ObfuscatedText;

=head1 NAME

pfappserver::Form::Field::ObfuscatedText

=head1 DESCRIPTION

This field extends the Text field to obfuscate the content but still support placeholders

=cut

use HTML::FormHandler::Moose;
extends 'HTML::FormHandler::Field::Text';

use pf::util;
use namespace::autoclean;

has '+type_attr'        => ( default => 'password' );

sub BUILD {
    my ($self, @args) = @_;
    $self->add_element_class(qw(pf-obfuscated-text));
    $self->set_tag('input_append_button', '<i class="icon-eye"></i>');
}

=head2 element_attributes

Add the x-placeholder attribute if the placeholder field exists

=cut

sub element_attributes {
    my ( $self, @args ) = @_;
    my $attr = $self->SUPER::element_attributes(@args);
    if (exists $attr->{placeholder} && defined $attr->{placeholder}) {
        $attr->{'x-placeholder'} = $attr->{placeholder};
        $attr->{placeholder} =~ s/./\*/g;
    }

    $attr->{autocomplete} = 'off';
    return $attr;
}

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

__PACKAGE__->meta->make_immutable unless $ENV{"PF_SKIP_MAKE_IMMUTABLE"};

1;
