package pfappserver::Form::Config::Scan;

=head1 NAME

pfappserver::Form::Config::Scan - Web form for Scan engine

=head1 DESCRIPTION

Form definition to create or update a scan engine.

=cut

use HTML::FormHandler::Moose;
extends 'pfappserver::Base::Form';
with 'pfappserver::Base::Form::Role::Help';

use pf::config;
use pf::util;
use File::Find qw(find);

## Definition
has 'roles' => (is => 'ro', default => sub {[]});

has_field 'id' =>
  (
   type => 'Text',
   label => 'Identifiant',
   required => 1,
   messages => { required => 'Please specify the hostname or IP of the Firewall' },
  );
has_field 'type' =>
  (
   type => 'Select',
   label => 'Scan Type',
   options_method => \&options_type,
  );
has_field 'categories' =>
  (
   type => 'Select',
   multiple => 1,
   label => 'Roles',
   options_method => \&options_categories,
   element_class => ['chzn-select'],
   element_attr => {'data-placeholder' => 'Click to add a role'},
   tags => { after_element => \&help,
             help => 'Nodes with the selected roles will be affected' },
  );

=head2 Methods

=cut

=head2 options_type

Dynamically extract the descriptions from the various Scan modules.

=cut

sub options_type {
    my $self = shift;

    my %paths = ();
    my $wanted = sub {
        if ((my ($module, $pack, $scan) = $_ =~ m/$lib_dir\/((pf\/scan\/([A-Z0-9][\w\/]+))\.pm)\z/)) {
            $pack =~ s/\//::/g; $scan =~ s/\//::/g;

            # Parent folder is the vendor name
            my @p = split /::/, $scan;
            my $vendor = shift @p;

            # Only switch types with a 'description' subroutine are displayed
            require $module;
            if ($pack->can('description')) {
                $paths{$vendor} = {} unless ($paths{$vendor});
                $paths{$vendor}->{$scan} = $pack->description;
            }
        }
    };
    find({ wanted => $wanted, no_chdir => 1 }, ("$lib_dir/pf/scan"));

    # Sort vendors and switches for display
    my @modules;
    foreach my $vendor (sort keys %paths) {
        my @scan = map {{ value => $_, label => $paths{$vendor}->{$_} }} sort keys %{$paths{$vendor}};
        push @modules, { group => $vendor,
                         options => \@scan };
    }

    return @modules;
}

=head2 options_categories

=cut

sub options_categories {
    my $self = shift;

    my ($status, $result) = $self->form->ctx->model('Roles')->list();
    my @roles = map { $_->{name} => $_->{name} } @{$result} if ($result);
    return ('' => '', @roles);
}

=head2 ACCEPT_CONTEXT

To automatically add the context to the Form

=cut

sub ACCEPT_CONTEXT {
    my ($self, $c, @args) = @_;
    my @oses = ["Windows" => "Windows",
                "Mac OS" => "Mac OS",
                "Android" => "Android",
                "Apple" => "Apple IOS device"
               ];
    return $self->SUPER::ACCEPT_CONTEXT($c, oses => @oses, @args);
}


=over

=back

=head1 COPYRIGHT

Copyright (C) 2014 Inverse inc.

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
