package pfappserver::Form::Config::Source::Htpasswd;

=head1 NAME

pfappserver::Form::Config::Source::Htpasswd - Web form for a htpasswd user source

=head1 DESCRIPTION

Form definition to create or update a htpasswd user source.

=cut

use HTML::FormHandler::Moose;
use pf::Authentication::Source::HtpasswdSource;
extends 'pfappserver::Form::Config::Source';
with 'pfappserver::Base::Form::Role::Help', 'pfappserver::Base::Form::Role::InternalSource';

# Form fields
has_field 'path' =>
  (
   type => 'Path',
   label => 'File Path',
   required => 1,
   element_class => ['input-xxlarge'],
   # Default value needed for creating dummy source
   default => '',
  );

=head2 validate

Make sure the htpasswd file is readable.

=cut

sub validate {
    my $self = shift;

    $self->SUPER::validate();
    my $path = $self->value->{path};
    unless (defined($path) && -r $path) {
        $self->field('path')->add_error("The file is not readable by the user 'pf'.");
    }
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
