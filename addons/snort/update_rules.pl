#!/usr/bin/perl -w

=head1 NAME

update_rules.pl

=head1 DESCRIPTION

Obtain the last rules for snort

=cut

my %snort_rules_version =
  (
   "RHEL5" => "snort-2.8.6",
   "RHEL6" => "snort-2.9.0",
   "latest" => "snort-2.9.0",
   "Squeeze" => "snort-2.8.4",
   "Wheezy" => "snort-2.9.0"
  );

my %oses =
  (
   "CentOS release 5" => "RHEL5",
   "Red Hat Enterprise Linux Server release 5" => "RHEL5",
   "CentOS Linux release 6" => "RHEL6",
   "CentOS release 6" => "RHEL6",
   "Red Hat Enterprise Linux Server release 6" => "RHEL6",
   "6" => "Squeeze",
   "7" => "Wheezy"
  );

my $os_type = supported_os();
die "Your Linux distro is not supported or unknown." unless $os_type;

my @rule_files =
  (
   'emerging-botcc.rules',
   'emerging-attack_response.rules',
   'emerging-exploit.rules',
   'emerging-malware.rules',
   'emerging-p2p.rules',
   'emerging-scan.rules',
   'emerging-shellcode.rules',
   'emerging-trojan.rules',
   'emerging-virus.rules',
   'emerging-worm.rules'
  );

foreach my $current_rule_file (@rule_files) {
    my $url = sprintf('http://rules.emergingthreats.net/open/%s/rules/%s', $snort_rules_version{$os_type}, $current_rule_file);
    `/usr/bin/wget -N $url -P /usr/local/pf/conf/snort/ > /dev/null 2>&1`;
    if ($?) {
        print "An error occured while downloading $url ($?)\n";
    } else {
        print "Downloaded $url\n";
    }
}

sub supported_os {

    # RedHat and derivatives
    if ( -e "/etc/redhat-release" ) {
        my $rhrelease_fh;
        open( $rhrelease_fh, '<', "/etc/redhat-release" );
        $version = <$rhrelease_fh>;
        close($rhrelease_fh);
    }
    # Debian and derivatives
    elsif (-e "/etc/debian_version" ) {
        my $debianversion;
        open( $debianversion, '<', "/etc/debian_version" );
        $version = <$debianversion>;
        close($debianversion);
    }
    # Unknown
    else {
        $version = "X";
    }

    foreach my $supported ( keys(%oses) ) {
        return ( $oses{$supported} ) if ( $version =~ /^$supported/ );
    }
    return (0);
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

