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

use JSON::MaybeXS;
use pf::log;
use pf::IniFiles;
use List::MoreUtils qw(uniq);

use base 'pfconfig::namespaces::resource';

sub init {
    my ($self) = @_;
    $self->{expandable_params} = [];
    $self->{child_resources}   = [];
    $self->{added_params}      = {};
}

sub _parse_error {
    my ($self) = @_;
    my $message = "Can't parse ".$self->{file}. " : ".join(', ', @pf::IniFiles::errors);
    print STDERR "$message\n";
    get_logger->error($message);
    $self->{parse_error} = $message;
}

sub build {
    my ($self) = @_;

    my %tmp_cfg;

    $self->{added_params}->{-file} = $self->{file};
    $self->{added_params}->{-allowempty} = 1;

    tie %tmp_cfg, 'pf::IniFiles', %{$self->{added_params}} or $self->_parse_error();

    @{ $self->{ordered_sections} } = keys %tmp_cfg;

    my $json = encode_json( \%tmp_cfg );
    my $cfg  = decode_json($json);

    $self->unarray_parameters($cfg);

    $self->{cfg} = $cfg;

    $self->do_defaults();

    my $child_resource = $self->build_child();
    $self->{cfg} = $child_resource;
    return $child_resource;
}

sub do_defaults {
    my ($self)  = @_;
    my $logger  = get_logger;
    my %tmp_cfg = %{ $self->{cfg} };
    unless ( defined( $self->{default_section} ) ) {
        $logger->debug("No default section defined when building $self->{file}");
        return;
    }
    foreach my $section_name ( keys %tmp_cfg ) {
        unless ( $section_name eq $self->{default_section} ) {
            foreach my $element_name ( keys %{ $tmp_cfg{ $self->{default_section} } } ) {
                unless ( exists $tmp_cfg{$section_name}{$element_name} ) {
                    $tmp_cfg{$section_name}{$element_name}
                        = $tmp_cfg{ $self->{default_section} }{$element_name};
                }
            }
        }
    }
    $self->{cfg} = \%tmp_cfg;
}

sub unarray_parameters {
    my ( $self, $hash ) = @_;
    foreach my $data ( values %$hash ) {
        foreach my $key ( keys %$data ) {
            next unless defined $data->{$key};
            $data->{$key}
                = ref( $data->{$key} ) eq 'ARRAY' ? join( "\n", @{ $data->{$key} } ) : $data->{$key};
        }
    }
}

sub cleanup_whitespaces {
    my ( $self, $hash ) = @_;
    foreach my $data ( values %$hash ) {
        foreach my $key ( keys %$data ) {
            next unless defined $data->{$key};
            $data->{$key} =~ s/\s+$//;
        }
    }
}

=head2 expand_list

=cut

sub expand_list {
    my ( $self, $object, @columns ) = @_;
    foreach my $column (@columns) {
        if ( exists $object->{$column} ) {
            $object->{$column} = [ $self->split_list( $object->{$column} ) ];
        }
    }
}

sub split_list {
    my ( $self, $list ) = @_;
    return split( /\s*,\s*/, $list );
}

sub GroupMembers {
    my ( $self, $group ) = @_;
    my @members;
    foreach my $key ( @{ $self->{ordered_sections} } ) {
        my @values = split( ' ', $key );
        if ( @values > 1 && $values[0] eq $group ) {
            push @members, $key;
        }
    }
    return @members;
}

sub updateRoleReverseLookup {
    my ($self, $id, $item, $namespace, @fields) = @_;
    my @categories;
    for my $field (@fields) {
        next unless exists $item->{$field};
        my $value = $item->{$field};
        next if !defined $value;;
        if (ref($value) eq '') {
            $value = [split /\s*,\s*/, $value];
        }

        push @categories, @$value;
    }

    @categories = uniq @categories;
    for my $c (@categories) {
        push @{$self->{roleReverseLookup}{$c}{$namespace}}, $id;
    }
}

=head1 AUTHOR

Inverse inc. <info@inverse.ca>

=head1 COPYRIGHT

Copyright (C) 2005-2020 Inverse inc.

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

