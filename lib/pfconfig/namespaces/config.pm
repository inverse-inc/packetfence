package pfconfig::namespaces::config;

=head1 NAME

pfconfig::namespaces::config

=cut

=head1 DESCRIPTION

General class that allows to build a configuration hash an ini file.

This ini file is parsed using Config::Inifiles

=head1 USAGE

In order to use it with a configuration file :
- Create a subclass in pfconfig/namespaces/config
- Implement the init method and initialize at least the file attribute
to the file path of the configuration file
- You can also implement the build_child method that is executed after
the build method and has access to the configuration hash through 
the attribute cfg 

=cut

use strict;
use warnings;

use Data::Dumper;
use JSON;

use base 'pfconfig::namespaces::resource';

sub build {
  my ($self) = @_;

  my %tmp_cfg;

  tie %tmp_cfg, 'Config::IniFiles', ( -file => $self->{file} );

  my $json = encode_json(\%tmp_cfg);
  my $cfg = decode_json($json);

  $self->{cfg} = $cfg;

  my $child_resource = $self->build_child();
  return $child_resource;
}

=head2 expand_list

=cut

sub expand_list {
    my ( $self,$object,@columns ) = @_;
    foreach my $column (@columns) {
        if (exists $object->{$column}) {
            $object->{$column} = [ $self->split_list($object->{$column}) ];
        }
    }
}

sub split_list {
    my ($self,$list) = @_;
    return split(/\s*,\s*/,$list);
}



=back

=head1 AUTHOR

Inverse inc. <info@inverse.ca>

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

1;

# vim: set shiftwidth=4:
# vim: set expandtab:
# vim: set backspace=indent,eol,start:

