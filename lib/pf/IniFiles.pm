package pf::IniFiles;

=head1 NAME

pf::IniFiles add documentation

=cut

=head1 DESCRIPTION

pf::IniFiles

Additional functionality for Config::IniFiles

=cut

use strict;
use warnings;

use Config::IniFiles;
use base qw(Config::IniFiles);
use Time::HiRes qw(stat time);

*errors = \@Config::IniFiles::errors;
use List::MoreUtils qw(all first_index);

=head2 DeleteSection ( $sect_name, $include_groupmembers )

Completely removes the entire section from the configuration optionally groupmembers.

=cut

sub DeleteSection {
    my ($self,$sect,$include_groupmembers) = @_;
    return unless $self->SectionExists($sect);
    my $result =  $self->SUPER::DeleteSection($sect);
    if ($result) {
        if ($include_groupmembers) {
            foreach my $group_member ($self->GroupMembers($sect)) {
                $self->DeleteSection($group_member,$include_groupmembers);
            }
        }
    }
    return $result;
} # end DeleteSection

=head2 RenameSection ( $old_section_name, $new_section_name, $include_groupmembers)

Renames a section if it does not already exists optionally including groupmembers

=cut

sub RenameSection {
    my $self = shift;
    my $old_sect = shift;
    my $new_sect = shift;
    my $include_groupmembers = shift;
    return undef unless $self->CopySection($old_sect,$new_sect,$include_groupmembers);
    return $self->DeleteSection($old_sect,$include_groupmembers);

} # end RenameSection

=head2 CopySection ( $old_section_name, $new_section_name, $include_groupmembers)

Copies one section to another optionally including groupmembers

=cut

sub CopySection {
    my $self = shift;
    my $old_sect = shift;
    my $new_sect = shift;
    my $include_groupmembers = shift;

    if (not defined $old_sect or
        not defined $new_sect or
        !$self->SectionExists($old_sect) or
        $self->SectionExists($new_sect)) {
        return undef;
    }

    $self->_caseify(\$new_sect);
    $self->_AddSection_Helper($new_sect);

    # This is done the fast way, change if data structure changes!!
    foreach my $key (qw(v sCMT pCMT EOT parms myparms)) {
        next unless exists $self->{$key}{$old_sect};
        $self->{$key}{$new_sect} = Config::IniFiles::_deepcopy($self->{$key}{$old_sect});
    }

    if($include_groupmembers) {
        foreach my $old_groupmember ($self->GroupMembers($old_sect)) {
            my $new_groupmember = $old_groupmember;
            $new_groupmember =~ s/\A\Q$old_sect\E/$new_sect/;
            $self->CopySection($old_groupmember,$new_groupmember);
        }
    }

    return 1;
} # end CopySection


=head2 ResortSections

=cut

sub ResortSections {
    my ($self,@sections) = @_;
    my $result;
    if (all { $self->SectionExists($_) } @sections ) {
        my $first_section = $sections[0];
        my $first_index = first_index { $_ eq $first_section } $self->Sections;
        my %temp;
        @temp{@sections} = ();
        my @old_sections = $self->Sections;
        my $old_length = $#old_sections;
        my @before = grep {!exists $temp{$_} } @old_sections[0 .. $first_index];
        $first_index++;
        my @after = grep {!exists $temp{$_} } @old_sections[$first_index .. $#old_sections];
        $self->{sects} = [@before,@sections,@after];
        $result = 1;
    }
    return $result;
} # end ResortSections

=head2 ReorderByGroup

=cut

sub ReorderByGroup {
    my ($self) = @_;
    my @sections = $self->Sections;
    if (@sections) {
        # Finding all non group sections
        my @non_group = grep { !/ / } @sections;
        if (scalar @sections != scalar @non_group) {
            my @new_sections;
            my @groups = grep { / / } @sections;
            foreach my $section (@non_group) {
                push @new_sections, $section, grep { /^\Q$section \E/ } @groups;
                @groups = grep { !/^\Q$section \E/ } @groups;
            }
            # Push any remaining group sections
            push @new_sections, @groups;
            $self->{sects} = \@new_sections;
        }
    }
}

=head1 IsExpired

=cut

sub IsExpired {
    my ($self,$no_check_imported) = @_;
    my $imported_expired = 0;
    if(!$no_check_imported && exists $self->{imported}) {
        my $imported = $self->{imported};
        $imported_expired = $imported->IsExpired() if defined $imported;
    }
    my $last_mod_timestamp = $self->GetLastModTimestamp;
    my $current_mod_timestamp = $self->GetCurrentModTimestamp;
    return ($imported_expired || (defined $last_mod_timestamp && $last_mod_timestamp < $current_mod_timestamp));
}

=head1 HasChanged

Verify if the has

=cut

sub HasChanged {
    my ($self,$no_check_imported) = @_;
    my $imported_expired = 0;
    if(!$no_check_imported && exists $self->{imported}) {
        my $imported = $self->{imported};
        $imported_expired = $imported->HasChanged() if defined $imported;
    }
    my $last_mod_timestamp = $self->GetLastModTimestamp;
    my $result = $imported_expired || (defined $last_mod_timestamp && $last_mod_timestamp != $self->GetCurrentModTimestamp );
    return $result;
}


=head2 SetLastModTimestamp

Sets the current typestamp of the file

=cut

sub SetLastModTimestamp {
    my ($self) = @_;
    $self->{_last_timestamp} = $self->GetCurrentModTimestamp();
}


=head2 GetLastModTimestamp

Gets the mod typestamp of the file

=cut

sub GetLastModTimestamp { $_[0]->{_last_timestamp} || -1; }

=head2 GetCurrentModTimestamp

Gets the current typestamp of the file

=cut

sub GetCurrentModTimestamp {
    my ($self) = @_;
    return _getFileTimestamp($self->GetFileName);
}

sub _getFileTimestamp {
    my $timestamp = (stat($_[0]))[9];
    if (defined $timestamp) {
        $timestamp *= 1_000_000_000;
        $timestamp = int($timestamp)
    } else {
        $timestamp = -1;
    }
    return $timestamp;
}


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

