package pfappserver::Form::Config::FingerbankSetting;

=head1 NAME

pfappserver::Form::Config::FingerbankSetting - Web form for fingerbank.conf

=head1 DESCRIPTION

Form definition to create or update a section of fingerbank.conf

=cut

use HTML::FormHandler::Moose;
extends 'pfappserver::Base::Form';
with 'pfappserver::Base::Form::Role::Help';
with 'pfappserver::Base::Form::Role::Defaults';
use pfconfig::cached_hash;
use pf::log;
tie our %Doc_Config, 'pfconfig::cached_hash', 'config::FingerbankDoc';
tie our %Defaults, 'pfconfig::cached_hash', 'config::FingerbankSettingsDefaults';

has 'section' => ( is => 'ro' );

=head2 build_field_info

build_field

=cut

sub build_field_info {
    my ($self, $section, $name) = @_;
    my $doc = $Doc_Config{$section}{$name};
    my $field = {
        id   => $name,
        name => $name,
        type => $self->field_type( $section, $name, $doc ),
        element_attr => {
            placeholder => $Defaults{$section}{$name}
        },
        tags => {
            after_element => \&help,
            help => do {
                my $d = $doc->{description};
                $d = join( "\n", @$d ) if ref($d) eq 'ARRAY';
                $d;
            },
        }
    };
    my $type = $doc->{type};
    my $method = "build_${type}_field";
    $self->$method($field, $section, $name, $doc);
    return $field;
}

=head2 build_toggle_field

build_toggle_field

=cut

sub build_toggle_field {
    my ($self, $field, $section, $name, $doc) = @_;
    $field->{checkbox_value}  = 'enabled';
    $field->{unchecked_value} = 'disabled';
    return ;
}

=head2 build_numeric_field

build_numeric_field

=cut

sub build_numeric_field {
    my ($self, $field, $section, $name, $doc) = @_;
    return ;
}

=head2 build_text_field

build_text_field

=cut

sub build_text_field {
    my ($self, $field, $section, $name, $doc) = @_;
    $field->{element_class} = ['input-xxlarge'];
    return ;
}

my %DOC_TYPE_2_FIELD_TYPE = (
    numeric => 'PosInteger',
    text => 'Text',
    toggle => 'Toggle',
);

=head2 field_type

field_type

=cut

sub field_type {
    my ($self, $section, $name, $doc) = @_;
    return $DOC_TYPE_2_FIELD_TYPE{$doc->{type}};
}

=head2 field_list

Dynamically build the field list from the 'section' instance attribute.

=cut

sub field_list {
    my $self = shift;
    my $section = $self->section;
    return [] if !defined $section;
    my @list;
    
    foreach my $name (keys %{$Doc_Config{$section}} ) {
        push @list, $self->build_field_info($section, $name);
    }

    return \@list;
}

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

__PACKAGE__->meta->make_immutable unless $ENV{"PF_SKIP_MAKE_IMMUTABLE"};
1;
