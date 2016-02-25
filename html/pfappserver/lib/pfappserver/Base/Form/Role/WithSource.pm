package pfappserver::Base::Form::Role::WithSource;

=head1 NAME

pfappserver::Base::Form::Role::MultiSource

=head1 DESCRIPTION

Role for MultiSource portal modules

=cut

use HTML::FormHandler::Moose::Role;
with 'pfappserver::Base::Form::Role::Help';

use pf::log;

after 'setup' => sub {
    my ($self) = @_;

    if($self->for_module->does('captiveportal::DynamicRouting::MultiSource')){
        $self->field('source_id')->multiple(1);
        $self->field('source_id')->options([$self->options_sources(multiple => 1)]);
    }
    else {
        $self->field('source_id')->options([$self->options_sources(multiple => 0)]);
    }

};

has_field 'source_id' =>
  (
   type => 'Select',
   label => 'Sources',
   options => [],
   element_class => ['chzn-select'],
   element_attr => {'data-placeholder' => 'Click to add a source'},
   tags => { after_element => \&help,
             help => 'The sources to use in the module. If no sources are specified, all the sources on the Portal Profile will be used' },
  );


sub options_sources {
    my ($self, %options) = @_;
    require pf::authentication;
    my @sources;
    foreach my $source (@{pf::authentication::getAllAuthenticationSources()}){
        # We are dealing with a multi source module, meaning we are looking for the isa in the sources attribute
        my ($isa);
        if($options{multiple} && $self->for_module->meta->get_attribute('sources')->{isa} =~ /^ArrayRef\[(.*)\]/){
            $isa = $1;
        }
        else {
            $isa = $self->for_module->meta->get_attribute('source')->{isa};
        }
        get_logger->debug("Building options with isa : $isa");
        foreach my $splitted_isa (split(/\s*\|\s*/, $isa)){
            if($source->isa($splitted_isa)){
                push @sources, $source->id;
                last;
            }
        }
    }
    get_logger->debug(sub { use Data::Dumper; "The following sources are available : ".Dumper(\@sources) });
    return map { {value => $_, label => $_} } @sources;
}

=head1 AUTHOR

Inverse inc. <info@inverse.ca>

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

1;


