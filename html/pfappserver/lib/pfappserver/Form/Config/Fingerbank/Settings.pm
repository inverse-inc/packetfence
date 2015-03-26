package pfappserver::Form::Config::Fingerbank::Settings;

=head1 NAME

pfappserver::Form::Config::Fingerbank::Settings

=head1 DESCRIPTION

Form definition to modify Fingerbank configuration

=cut

use HTML::FormHandler::Moose;

extends 'pfappserver::Base::Form';
with 'pfappserver::Base::Form::Role::Help';

has 'section' => ( is => 'ro' );

sub field_list {
    my ( $self ) = @_;

    my $list = [];

    my $config = fingerbank::Config::get_config;
#    my @sections = keys %$config;
#    push @$list, map{$_ => { id => $_, type => 'Compound' } } @sections;
    foreach my $section ( keys %$config ) {
        push @$list, $section => {id => $section, type => 'Compound'};
        foreach my $parameter ( keys %{$config->{$section}} ) {
            my $field = {
                id => $section . "." . $parameter,
                type => 'Text',
            };
            push ( @$list, $parameter => $field );
        }
    }

    return $list;


#    my $section = $self->section;
#
#    my @section_fields;
#    my $config = fingerbank::Config::get_config($section);
#    foreach my $field ( keys %$config ) {
#        push @section_fields, $field;
#    }
#
#    foreach my $name ( @section_fields ) {
#        my $field = {
#            id => $name,
#            type => 'Text',
#        };
#        push ( @$list, $name => $field );
#    }
#
#    return $list;
}

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

__PACKAGE__->meta->make_immutable;
1;
