package pf::cmd::pf::checkrequirements;
=head1 NAME

pf::cmd::pf::checkrequirements

=head1 SYNOPSIS

pfcmd checkrequirements

Check system hardware requirements for PacketFence

=head1 DESCRIPTION

pf::cmd::checkrequirements

=cut

use strict;
use warnings;
use pf::constants::exit_code qw($EXIT_SUCCESS $EXIT_FAILURE);
use base qw(pf::cmd);

# Recommended requirements
use constant RECOMMENDED_RAM_GB  => 8;
use constant RECOMMENDED_CPU     => 8;
use constant RECOMMENDED_DISK_GB => 50;

sub _run {
    my ($self) = @_;
    
    print "=" x 50 . "\n";
    print "PacketFence System Requirements Check\n";
    print "=" x 50 . "\n\n";
    
    # Get actual system specs
    my $total_ram_gb = $self->_get_ram_gb();
    my $total_cpu = $self->_get_cpu_count();
    my $total_disk_gb = $self->_get_disk_gb();
    
    print "System Specifications:\n";
    printf "  RAM:  %d GB (Recommended: %d GB)\n", $total_ram_gb, RECOMMENDED_RAM_GB;
    printf "  CPU:  %d cores (Recommended: %d cores)\n", $total_cpu, RECOMMENDED_CPU;
    printf "  Disk: %d GB (Recommended: %d GB)\n", $total_disk_gb, RECOMMENDED_DISK_GB;
    print "\n";
    
    my $warnings = 0;
    
    if ($total_ram_gb < RECOMMENDED_RAM_GB) {
        print "WARNING: RAM is below recommended specifications!\n";
        $warnings++;
    }
    
    if ($total_cpu < RECOMMENDED_CPU) {
        print "WARNING: CPU cores are below recommended specifications!\n";
        $warnings++;
    }
    
    if ($total_disk_gb < RECOMMENDED_DISK_GB) {
        print "WARNING: Disk space is below recommended specifications!\n";
        $warnings++;
    }
    
    if ($warnings == 0) {
        print "✓ All requirements met!\n";
    } else {
        print "\n";
        print "⚠ $warnings warning(s) found. PacketFence may not perform optimally.\n";
        print "  For production use, please ensure the recommended specifications.\n";
    }
    
    print "=" x 50 . "\n";
    
    return $warnings > 0 ? $EXIT_FAILURE : $EXIT_SUCCESS;
}

sub _get_ram_gb {
    my ($self) = @_;
    my $ram_kb = `grep MemTotal /proc/meminfo | awk '{print \$2}'`;
    chomp($ram_kb);
    return int($ram_kb / 1024 / 1024);
}

sub _get_cpu_count {
    my ($self) = @_;
    my $cpu_count = `nproc`;
    chomp($cpu_count);
    return int($cpu_count);
}

sub _get_disk_gb {
    my ($self) = @_;
    my $disk_output = `df -BG / | awk 'NR==2 {print \$2}'`;
    chomp($disk_output);
    $disk_output =~ s/G//;
    return int($disk_output);
}

=head1 AUTHOR

Inverse inc. <info@inverse.ca>

=head1 COPYRIGHT

Copyright (C) 2005-2025 Inverse inc.

=head1 LICENSE

This program is free software; you can redistribute it and::or
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
