package pfappserver::Model::Config::Profile::Default;

=head1 NAME

pfappserver::Model::Config::Cached::Profile::Default;

=cut

=head1 DESCRIPTION

Maps the Default Profile from the different values in the pf.conf

=cut

use Moose;
use namespace::autoclean;
use pf::config::cached;
use pf::config;

extends 'pfappserver::Base::Model::Config::Cached::Mapped';


=head2 fields

=cut

has '+mapping' => ( builder => '_buildMapping');

=head1 METHODS


=head2 _buildMapping

builds the mapping hash

=cut

our %MAPPING = (
    logo => [qw(general logo)],
    guest_self_reg => [qw(registration guests_self_registration)],
    guest_modes => [qw(guests_self_registration modes)],
    billing_engine => [qw(registration billing_engine)],
);

sub _buildMapping { \%MAPPING}

=head2 _buildCachedConfig

=cut

sub _buildCachedConfig { $cached_pf_config }

sub cleanupAfterRead {
    my ( $self,$section, $assignment ) = @_;
    my $mapping = $self->mapping;
    while(my ($key,$value) = each %$assignment) {
        next unless exists $mapping->{$key};
        my ($section,$param) = @{$mapping->{$key}};
        my $defaults = $Default_Config{$section};
        my $doc_section = "$section.$param";
        my $doc = $Doc_Config{$doc_section};
        my $type = $doc->{type} || "text";
        if ($type eq "toggle" || $type eq "time") {
            $assignment->{$key} = $Default_Config{$section}{$param} unless $value;
        } elsif ($type eq "date") {
            my $time = str2time($assignment->{$key} || $Default_Config{$section}{$param});
            # Match date format of Form::Widget::Theme::Pf
            $assignment->{$key} = POSIX::strftime("%Y-%m-%d", localtime($time));
        } elsif ($type eq 'multi') {
            my @values = split( /\s*,\s*/, $value ) if $value;
            $assignment->{$key} = \@values;
        }
    }

}

sub cleanupBeforeCommit {
    my ( $self,$section, $assignment ) = @_;
    while(my ($key,$value) = each %$assignment) {
        if(ref($value) eq 'ARRAY') {
            $assignment->{$key} = join(',',@$value);
        }
    }
}

__PACKAGE__->meta->make_immutable;

=head1 COPYRIGHT

Copyright (C) 2013 Inverse inc.

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

