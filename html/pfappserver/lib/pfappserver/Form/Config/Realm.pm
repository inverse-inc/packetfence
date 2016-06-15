package pfappserver::Form::Config::Realm;

=head1 NAME

pfappserver::Form::Config::Realm - Web form for a floating device

=head1 DESCRIPTION

Form definition to create or update realm.

=cut

use HTML::FormHandler::Moose;
extends 'pfappserver::Base::Form';
with 'pfappserver::Base::Form::Role::Help';

use pf::config;
use pf::authentication;
use pf::util;

has domains => ( is => 'rw');
has sources => ( is => 'rw');

## Definition
has_field 'id' =>
  (
   type => 'Text',
   label => 'Realm',
   required => 1,
   messages => { required => 'Please specify a Realm' },
   apply => [ pfappserver::Base::Form::id_validator('realm') ]
  );

has_field 'options' =>
  (
   type => 'TextArea',
   label => 'Realm Options',
   required => 0,
   default => 'strip',
   tags => { after_element => \&help,
             help => 'You can add options in the realm definition' },
  );

has_field 'domain' =>
  (
   type => 'Select',
   multiple => 0,
   label => 'Domain',
   options_method => \&options_domains,
   element_class => ['chzn-deselect'],
   element_attr => {'data-placeholder' => 'Click to select a domain'},
   tags => { after_element => \&help,
             help => 'The domain to use for the authentication in that realm' },
  );

has_field 'source' =>
  (
   type => 'Select',
   multiple => 0,
   label => 'Source',
   options_method => \&options_sources,
   element_class => ['chzn-deselect'],
   element_attr => {'data-placeholder' => 'Click to select a source'},
   tags => { after_element => \&help,
             help => 'The authentication source to use in that realm.<br/>(Must also be defined in the portal profile)' },
  );



=head2 options_roles

=cut

sub options_domains {
    my $self = shift;
    my @domains = map { $_->{id} => $_->{id} } @{$self->form->domains} if ($self->form->domains);
    unshift @domains, ("" => "");
    return @domains;
}

=head2 options_sources

=cut

sub options_sources {
    my $self = shift;
    my @sources = map { $_->id => $_->id } @{$self->form->sources} if ($self->form->sources);
    unshift @sources, ("" => "");
    return @sources;
}

=head2 ACCEPT_CONTEXT

To automatically add the context to the Form

=cut

sub ACCEPT_CONTEXT {
    my ($self, $c, @args) = @_;
    my (undef, $domains) = $c->model('Config::Domain')->readAll();
    return $self->SUPER::ACCEPT_CONTEXT($c, domains => $domains, sources => pf::authentication::getInternalAuthenticationSources(), @args);
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
