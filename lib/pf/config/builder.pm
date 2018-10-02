package pf::config::builder;

=head1 NAME

pf::config::builder - the base class for building config from ini file

=head1 DESCRIPTION

Build the config from a config file

=cut

use strict;
use warnings;
use List::MoreUtils qw(uniq);

sub new {
    my ($proto) = @_;
    return bless {}, ref($proto) || $proto;
}

=head2 build

build the config data from an ini file

=cut

sub build {
    my ($self, $ini) = @_;
    my $buildData = $self->buildData($ini);
    return (@{$buildData}{qw(errors entries)});
}

=head2 skipEntry

Can the entry can be skipped

=cut

sub skipEntry {
    undef
}

=head2 getSectionData

getSectionData

=cut

sub getSectionData {
    my ($self, $ini, $section) = @_;
    my %data;
    my $default = $ini->{'default'} if exists $ini->{default};
    my @default_params = $ini->Parameters($default) if defined $default;
    for my $param (uniq $ini->Parameters($section), @default_params) {
        my $val = $ini->val($section, $param);
        $val =~ s/\s+$//;
        $data{$param} = $val;
    }

    return \%data;
}

=head2 buildData

build the data from an ini file

=cut

sub buildData {
    my ($self, $ini) = @_;
    my $buildData = {
        errors       => undef,
        entries      => {},
        ini_sections => [$ini->Sections],
        ini          => $ini
    };
    foreach my $id ( @{$buildData->{ini_sections}}) {
        my $entry = $self->getSectionData($ini, $id);
        next if $self->skipEntry($buildData, $id, $entry);
        if (defined ($entry = $self->buildEntry($buildData, $id, $entry))) {
            $buildData->{entries}{$id} = $entry;
        }
    }

    $self->cleanupBuildData($buildData);
    return $buildData;
}

=head2 buildEntry

build a config entry

=cut

sub buildEntry {
    my ($self, $buildData, $id, $entry) = @_;
    return $entry;
}

=head2 cleanupBuildData

cleanupBuildData

=cut

sub cleanupBuildData { }

=head1 AUTHOR

Inverse inc. <info@inverse.ca>

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

1;
