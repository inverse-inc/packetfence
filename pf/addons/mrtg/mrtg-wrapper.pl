#!/usr/bin/perl

=head1 NAME

mrtg-wrapper.pl - use of MRTG to provide long-term graphing of data

=head1 SYNOPSIS

./mrtg-wrapperl.pl -r <report_type> <options>

  Report_type:
    - registration
    - activity
    - violations

  Options:
    -h <hostname>
    -p <port>
    -u <user>
    -s <password>

=cut

#
# This wrapper allows for plug-and-play use of MRTG to provide long-term graphing of data
#

use strict;
use LWP;
#use LWP::Debug qw(+);
use File::Basename;
use Getopt::Std;

# If you'd prefer to not provide information on the command-line, set defaults here
use vars qw/$pf_host $pf_port $pf_user $pf_pass/;
$pf_host = '';
$pf_port = '';
$pf_user = '';
$pf_pass = '';

my %args;
getopts('h:p:u:s:r:', \%args);

my @valid_reports = ( 'registration', 'activity', 'violations');
my $report;

if (defined($args{h})) {
  $pf_host = $args{h};
} 
if (defined($args{p})) {
  $pf_port = $args{p};
}
if (defined($args{u})) {
  $pf_user = $args{u};
}
if (defined($args{s})) {
  $pf_pass = $args{s};
}
if (!defined($args{r})) {
  usage();
} elsif (!grep(/^$args{r}$/, @valid_reports)) {
  usage();
} else {
  $report = $args{r};
}

if ($report eq "registration") {
  print get_total("report registered active")."\n";
  print get_total("report unregistered active")."\n";
} elsif ($report eq "activity") {
  print get_total("report active")."\n";
  print get_total("report inactive")."\n";
} elsif ($report eq "violations") {
  print get_total("report openviolations active")."\n";
  print get_total("report openviolations all")."\n";
}
print "NONE\n";
print $pf_host."\n";

sub get_total {
  my ($command) = @_;
  my $pfcmd = "https://$pf_host:$pf_port/cgi-bin/pfcmd.cgi?ARGS=$command";
  my $ua = LWP::UserAgent->new;
  my $req = HTTP::Request->new(GET => $pfcmd);
  $req->authorization_basic($pf_user, $pf_pass);
  my $response = $ua->request($req);

  if (!$response->is_success) {
    die("Error: ".$response->status_line."\n");
  } else {
    my $total = scalar(split("\n", $response->content));
    if ($total > 0) {
      return($total - 1);
    } else {
      return(0);
    }
  }
}

sub usage {
   my $prog = basename($0);
   my $reports = join('|', @valid_reports);
   print STDERR << "EOF";
Usage:  $prog -r <$reports> [OPTIONS]
  -u                    PF administrative username
  -s                    PF administrative password
  -h                    PF hostname
  -p                    PF administration port

  activity: graph active vs inactive nodes
  violations: graph open violations on active nodes
  registration: graph active registered nodes against active unregistered nodes

EOF
  exit;
}

=head1 COPYRIGHT

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

