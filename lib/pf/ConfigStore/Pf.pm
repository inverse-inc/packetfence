package pf::ConfigStore::Pf;
=head1 NAME

pf::ConfigStore::PF add documentation

=cut

=head1 DESCRIPTION

pf::ConfigStore::PF

=cut

use Moose;
use namespace::autoclean;
use pf::config;

extends 'pf::ConfigStore';

=head2 Methods

=over

=item _buildCachedConfig

=cut

sub _buildCachedConfig { $cached_pf_config }

=item remove

Delete an existing item

=cut

sub remove { return; }

sub cleanupAfterRead {
    my ( $self,$section, $data ) = @_;
    my $defaults = $Default_Config{$section};
    foreach my $key ($cached_pf_config->Parameters($section) ) {
        my $doc_section = "$section.$key";
        unless (exists $Doc_Config{$doc_section} && exists $data->{$key}  ) {
            next;
        }
        my $doc = $Doc_Config{$doc_section};
        my $type = $doc->{type} || "text";
        # Value should always be defined for toggles (checkbox and select) and times (duration)
        if ($type eq "toggle" || $type eq "time") {
            $data->{$key} = $Default_Config{$section}{$key} unless ($data->{$key});
        } elsif ($type eq "date") {
            my $time = str2time($data->{$key} || $Default_Config{$section}{$key});
            # Match date format of Form::Widget::Theme::Pf
            $data->{$key} = POSIX::strftime("%Y-%m-%d", localtime($time));
        } elsif ($type eq 'multi') {
            my $value = $data->{$key};
            my @values = split( /\s*,\s*/, $value ) if $value;
            $data->{$key} = \@values;
        } elsif ( defined ($data->{$key}) && $data->{$key} eq $defaults->{$key}) {
            #remove default values
            $data->{$key} = undef;
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

=back

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

