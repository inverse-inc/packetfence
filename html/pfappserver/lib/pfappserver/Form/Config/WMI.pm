package pfappserver::Form::Config::WMI;

=head1 NAME

pfappserver::Form::Config::WMI - Web form for a WMI

=head1 DESCRIPTION

Form definition to create or update WMI.

=cut

use HTML::FormHandler::Moose;
extends 'pfappserver::Base::Form';
with 'pfappserver::Base::Form::Role::Help';

use pf::config;
use pf::util;

## Definition
has_field 'id' =>
  (
   type => 'Text',
   label => 'Name',
   required => 1,
   messages => { required => 'Please specify a name for the scan engine' },
   apply => [ pfappserver::Base::Form::id_validator('name') ]
  );

has_field 'on_tab' =>
  (
   type => 'Checkbox',
   label => 'On Node tab',
   checkbox_value => '1',
   unchecked_value => '0',
   tags => { after_element => \&help,
             help => 'Scan this WMI element while editing a node' },
  );

has_field 'request' =>
  (
   type => 'Text',
   label => 'Request',
   required => 1,
   messages => { required => 'Please specify the sql request like "select * from Win32_Product"' },
  );

has_field 'namespace' =>
  (
   type => 'Text',
   label => 'Namespace',
   required => 1,
   default => 'ROOT\cimv2',
   messages => { required => 'Please specify the namespace you want to use "ROOT\cimv2"' },
  );


has_field 'action' =>
  (
   type => 'TextArea',
   label => 'Rules Actions',
   required => 1,
   inflate_default_method => \&filter_inflate ,
   deflate_default_method => \&filter_deflate ,
   tags => { after_element => \&help,
             help => 'Add an action based on the result of the request' },
  );

has_block definition =>
  (
   render_list => [ qw( on_tab namespace request action) ],
  );

sub filter_inflate {
    my ($self, $value) = @_;
    if(ref($value) eq 'ARRAY' ) {
         return (join("\n",@{$value}));
    }
    return $value;
}

sub filter_deflate {
    my ($self, $value) = @_;
    return [split /\n/,$value];
}


=over

=back

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
