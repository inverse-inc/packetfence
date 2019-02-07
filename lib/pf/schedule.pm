package pf::schedule;

=head1 NAME

pf::schedule - module for scan schedule management

=head1 DESCRIPTION

  small cron obj
  _index wrapper functions for later move to Schedule::Cron
  we only need %10 of what Schedule::Cron does

=head1 BUGS AND LIMITATIONS

Currently, when used to schedule Nessus scans, there can't be
any other crontab entries for the 'pf' user. The module has
not yet the necessary logic to handle these different kinds
of scheduled tasks.

See http://packetfence.org/mantis/view.php?id=674

=cut

use strict;
use warnings;

sub new {
    my ($class) = @_;
    my $self;
    $self->{timetable} = [];
    bless $self, $class;
    return $self;
}

sub add_entry {
    my ( $self, $time, $args ) = @_;
    push @{ $self->{timetable} },
        {
        time => $time,
        args => $args
        };
    return 1;
}

sub list_entries {
    my ($self) = shift;
    my @ret;
    foreach my $entry ( @{ $self->{timetable} } ) {
        push @ret, $entry;
    }
    return @ret;
}

sub get_entry {
    my ( $self, $idx ) = @_;
    my $entry = $self->{timetable}->[$idx];
    if ( !$entry ) {
        return;
    }
    return ($entry);
}

sub delete_entry {
    my ( $self, $idx ) = @_;
    if ( $idx <= $#{ $self->{timetable} } ) {
        return splice @{ $self->{timetable} }, $idx, 1;
    } else {
        return;
    }
}

sub update_entry {
    my ( $self, $idx, $entry ) = @_;
    return unless $entry;
    return unless $entry->{time};
    if ( $idx <= $#{ $self->{timetable} } ) {
        $entry->{args} = [] unless $entry->{args};
        return splice @{ $self->{timetable} }, $idx, 1, $entry;
    } else {
        return;
    }
}

# load cron from $filename
sub load_cron {
    my ( $self, $filename ) = @_;
    $filename = "pf" if ( !$filename );
    my $file_fh;
    open( $file_fh, '<', "/var/spool/cron/" . $filename ) || return;
    my @array = <$file_fh>;
    foreach (@array) {
        my ( $min, $hour, $dmon, $month, $dweek, $rest )
            = split( /\s+/, $_, 6 );
        $rest =~ s/\\//g;
        chop($rest);
        my $date = join ' ', ( $min, $hour, $dmon, $month, $dweek );
        if ( $rest =~ /.*pfcmd.*$/ ) {
            $self->add_entry( $date, $rest );
        }
    }
    return 1;
}

# load cron from $filename
sub write_cron {
    my ( $self, $filename ) = @_;
    $filename = "pf" if ( !$filename );
    my $file_fh;
    open( $file_fh, '>', "/var/spool/cron/" . $filename );
    flock( $file_fh, 2 );
    foreach my $ref ( $self->list_entries() ) {
        $ref->{args} =~ s/;/\\;/g;
        print {$file_fh} "$ref->{time}\t$ref->{args}\n";
    }
    return 1;
}

# return all entries in table
sub get_indexes {
    my ( $self, $idx ) = @_;
    my @array;
    my $i         = 0;
    my $delimiter = "|";
    foreach my $ref ( $self->list_entries() ) {
        $ref->{args} =~ /now\s+(\S+).*/;
        push @array,
            join( $delimiter, ( $i++, $ref->{time}, $1 ) ) . "\n";
    }
    return @array;
}

sub delete_index {
    my ( $self, $idx ) = @_;
    return $self->delete_entry($idx);
}

sub add_index {
    my ( $self, $time, $args ) = @_;
    return $self->add_entry( $time, $args );
}

# return index int in table
sub get_index {
    my ( $self, $idx ) = @_;
    my @array;
    my $ref = $self->get_entry($idx);
    if (defined($ref)) {
        $ref->{args} =~ /now\s+(\S+).*/;
        return ( $idx, $ref->{time}, $1 );
    } else {
        return;
    }
}

# update index int in table with time/args
sub update_index {
    my ( $self, $idx, $time, $args ) = @_;
    return unless $args;
    return unless $time;
    my $entry = {
        time => $time,
        args => $args
    };
    return $self->update_entry( $idx, $entry );
}

=head1 AUTHOR

Inverse inc. <info@inverse.ca>

Minor parts of this file may have been contributed. See CREDITS.

=head1 COPYRIGHT

Copyright (C) 2005-2019 Inverse inc.

Copyright (C) 2005 Kevin Amorin

Copyright (C) 2005 David LaPorte

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
