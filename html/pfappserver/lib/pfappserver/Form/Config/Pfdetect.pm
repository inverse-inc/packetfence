package pfappserver::Form::Config::Pfdetect;

=head1 NAME

pfappserver::Form::Config::Pfdetect - Web form for a pfdetect detector

=head1 DESCRIPTION

Form definition to create or update a pfdetect detector.

=cut

use HTML::FormHandler::Moose;
extends 'pfappserver::Base::Form';
with 'pfappserver::Base::Form::Role::Help';

use pf::config;
use pf::util;
use pf::constants::pfdetect qw(@PFDETECT_PARSERS);

## Definition
has_field 'id' =>
  (
   type => 'Text',
   label => 'Detector',
   required => 1,
   messages => { required => 'Please specify a detector id' },
   apply => [ pfappserver::Base::Form::id_validator('detector id') ]
  );

has_field 'path' =>
  (
   type => 'Text',
   label => 'Alert pipe',
   required => 1,
   messages => { required => 'Please specify an alert pipe' },
  );

has_field 'type' =>
  (
   type => 'Select',
   multiple => 0,
   label => 'Type',
   options_method => \&options_parsers,
   element_class => ['chzn-deselect'],
   element_attr => {'data-placeholder' => 'Click to select a parser'},
   tags => { after_element => \&help,
             help => 'The parser to use for the alert pipe' },
  );

=head2 options_parsers

=cut

sub options_parsers {
    my $self = shift;
    my @parsers = map { $_ => $_ } pf::constants::pfdetect->modules;
    return @parsers;
}

=over

=back

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

__PACKAGE__->meta->make_immutable;
1;
