package pfappserver::Form::Field::Timezone;

=head1 NAME

pfappserver::Form::Field::Timezone

=head1 DESCRIPTION

Extends the select field to add a typeahead above it

=cut

use HTML::FormHandler::Moose;
extends 'HTML::FormHandler::Field::Select';

has '+widget' => ( default => 'Timezone' );

use namespace::autoclean;

use List::MoreUtils qw(any uniq);
use pf::error qw(is_success);
use pf::log;
use DateTime::TimeZone qw(all_names);
has '+deflate_value_method'=> ( default => sub { \&_deflate } );

=head2 build_options

Build the list of TimeZone available and order them by region

=cut

sub build_options {
    my ($self) = @_;
    # load options from DateTime::TimeZone
    my @options = all_names();
    return \@options;
};

=head2 after value

Modify the options to include only the base ones + the selected ones

=cut

after 'value' => sub {
    my ($self) = @_;
    my @base_ids = $self->fingerbank_model->base_ids();
    my @options = map {
        my ($status, $result) = $self->fingerbank_model->read($_);
        if(is_success($status)){
            { 
                value => $_,
                label => $result->{$self->fingerbank_model->value_field},
            }
        }
        else {
            ();
        }
    } uniq(@base_ids, @{$self->result->value()});
    $self->options(\@options);
};

sub _deflate {
    my ($self, $value) = @_;
    $value = [ uniq @$value ];
    return $value;
}


=head1 COPYRIGHT

Copyright (C) 2005-2017 Inverse inc.

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

