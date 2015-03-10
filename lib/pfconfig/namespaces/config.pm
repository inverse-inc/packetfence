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

sub init {
  my ($self) = @_;
  $self->{expandable_params} = [];
  $self->{child_resources} = [];
}

sub build {
  my ($self) = @_;

  my %tmp_cfg;

  tie %tmp_cfg, 'Config::IniFiles', ( -file => $self->{file} );

  my $json = encode_json(\%tmp_cfg);
  my $cfg = decode_json($json);

  $self->unarray_parameters($cfg);

  $self->{cfg} = $cfg;

  my $child_resource = $self->build_child();
  return $child_resource;
}

sub unarray_parameters {
    my ($self, $hash) = @_;
    foreach my $data (values %$hash ) {
        foreach my $key (keys %$data) {
            next unless defined $data->{$key};
            $data->{$key} = ref($data->{$key}) eq 'ARRAY' ? join("\n", @{$data->{$key}}) : $data->{$key};
        }
    }
}

sub cleanup_whitespaces {
    my ($self,$hash) = @_;
    foreach my $data (values %$hash ) {
        foreach my $key (keys %$data) {
            next unless defined $data->{$key};
            $data->{$key} =~ s/\s+$//;
        }
    }
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

sub normalize_time {
    my ($self, $date) = @_;
    my $TIME_MODIFIER_RE = qr/[smhDWMY]/;
    if ( $date =~ /^\d+$/ ) {
        return ($date);

    } else {
        my ( $num, $modifier ) = $date =~ /^(\d+)($TIME_MODIFIER_RE)/ or return (0);

        if ( $modifier eq "s" ) { return ($num);
        } elsif ( $modifier eq "m" ) { return ( $num * 60 );
        } elsif ( $modifier eq "h" ) { return ( $num * 60 * 60 );
        } elsif ( $modifier eq "D" ) { return ( $num * 24 * 60 * 60 );
        } elsif ( $modifier eq "W" ) { return ( $num * 7 * 24 * 60 * 60 );
        } elsif ( $modifier eq "M" ) { return ( $num * 30 * 24 * 60 * 60 );
        } elsif ( $modifier eq "Y" ) { return ( $num * 365 * 24 * 60 * 60 );
        }
    }
}

sub isenabled {
    my ($self, $enabled) = @_;
    if ( $enabled && $enabled =~ /^\s*(y|yes|true|enable|enabled|1)\s*$/i ) {
        return (1);
    } else {
        return (0);
    }
}

sub GroupMembers {
    my ($self, $group) = @_;
    my %cfg = %{$self->{cfg}};
    my @members;
    foreach my $key (keys %cfg){
        my @values = split (' ', $key);
        if (@values > 1 && $values[0] eq $group){
            push @members, $key;
        }
    }
    return @members;
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

