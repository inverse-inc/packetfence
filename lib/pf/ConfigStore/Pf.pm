package pf::ConfigStore::Pf;

=head1 NAME

pf::ConfigStore::PF add documentation

=cut

=head1 DESCRIPTION

pf::ConfigStore::PF

=cut

use Moo;
use namespace::autoclean;
use pf::config;
use pf::file_paths;

extends 'pf::ConfigStore';

=head2 Methods

=over

=item _buildCachedConfig

=cut

sub configFile {$pf_config_file};

sub pfconfigNamespace {'config::Pf'}

sub _buildCachedConfig {
    my ($self) = @_;
    my $cached_pf_default_config = pf::config::cached->new(-file => $default_config_file);
    my @args = (-file   => $config_file, -allowempty => 1, -import => $cached_pf_default_config);
    my $file = pf::config::cached->new(@args);
    return $file;
}

=item remove

Delete an existing item

=cut

sub remove { return; }

sub cleanupAfterRead {
    my ( $self,$section, $data ) = @_;
    my $defaults = $Default_Config{$section};
    foreach my $key ( keys %{$Config{$section}} ) {
        my $doc_section = "$section.$key";
        unless (exists $Doc_Config{$doc_section} && exists $data->{$key}  ) {
            next;
        }
        my $doc = $Doc_Config{$doc_section};
        my $type = $doc->{type} || "text";
        my $subtype = $doc->{subtype};
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
        } elsif ($type eq 'list') {
            my $value = $data->{$key};
            if ($value) {
                $data->{$key} = join("\n", split( /\s*,\s*/, $value));
            }
            elsif ($defaults->{$key}) {
                # No custom value, use default value
                $data->{$key} = join("\n", split( /\s*,\s*/, $defaults->{$key}));
            }
        } elsif ($type eq 'text_with_editable_default') {
            my $value = $data->{$key};
            $data->{$key} = $defaults->{$key} unless $value;
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
        my $doc_section = "$section.$key";
        if (exists $Doc_Config{$doc_section} ) {
            my $doc = $Doc_Config{$doc_section};
            my $type = $doc->{type} || "text";
            if($type eq 'list') {
                my $value = $assignment->{$key};
                $assignment->{$key} = join(",",split( /\v+/, $value )) if $value;
            }
        }
    }
}

__PACKAGE__->meta->make_immutable;

=back

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

