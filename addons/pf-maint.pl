#!/usr/bin/perl

=head1 NAME

pf-maint.pl

=cut

=head1 DESCRIPTION

pf-maint.pl is a script that allows user to download and keep track of all patches from the maintenance version of PacketFence

=head1 SYNOPSIS

pf-maint.pl [options]

 Options:
   -h --help               This help
   -c --commit             The last commit to be used for the diff: default the latest commit in the maintenance branch for version
   -b --base-commit        The base commit to be used for the diff: default the last commit save or the tag for version
   -u --github-user        The github user: default inverse-inc
   -r --github-repo        The github repo: default packetfence
   -n --no-ask             Do not ask to patch
   -d --pf-dir             The PacketFence directory
   -p --patch-bin          The patch binary default /usr/bin/patch

=cut

use strict;
use warnings;
use JSON::XS;
use File::Spec::Functions;
use File::Slurp;
use HTTP::Request;
use Getopt::Long;
use LWP::UserAgent;
use Pod::Usage;
use IO::Handle;
our $GITHUB_USER = 'inverse-inc';
our $GITHUB_REPO = 'packetfence';
our $PF_DIR      = $ENV{PF_DIR} || '/usr/local/pf';
our $help;
our $COMMIT;
our $BASE_COMMIT;
our $NO_ASK;
our $PATCH_BIN = '/usr/bin/patch';
our $COMMIT_ID_FILE = catfile($PF_DIR,'conf','git_commit_id');

GetOptions(
    "github-user|u=s" => \$GITHUB_USER,
    "github-repo|r=s" => \$GITHUB_REPO,
    "pf-dir|d=s"      => \$PF_DIR,
    "commit|c=s"      => \$COMMIT,
    "patch-bin|p=s"   => \$PATCH_BIN,
    "base-commit|b=s" => \$BASE_COMMIT,
    "no-ask|n"        => \$NO_ASK,
    "help|h"          => \$help
) or podusage(2);

pod2usage(1) if $help;

die "$PATCH_BIN does not exists or is not executable please install or make it executable" unless patch_bin_exists();

our $PATCHES_DIR = catdir( $PF_DIR, '.patches' );
mkdir $PATCHES_DIR or die "cannot create $PATCHES_DIR" unless -d $PATCHES_DIR;
our $PF_RELEASE_FULL = get_release_full();
our $PF_RELEASE_REV  = get_release_rev();

our $PF_RELEASE = $PF_RELEASE_REV;

our $BASE_GITHUB_URL =
  "https://api.github.com/repos/$GITHUB_USER/$GITHUB_REPO";

my $base = $BASE_COMMIT || get_base();

die "Cannot base commit\n" unless $base;

print "Currently at $base\n";

my $head = $COMMIT || get_head();
die "Already up to date\n" if $base eq $head;
print "Latest maintenance version is $head\n";

my $patch_data = get_patch_data( $base, $head );
show_patch($patch_data);
accept_patch() unless $NO_ASK;
print "Downloading the patch........\n";
save_patch( $patch_data, $base, $head );
print "Applying the patch........\n";
apply_patch( $patch_data, $base, $head );

sub get_release_full {
    chomp( my $release = read_file( catfile( $PF_DIR, 'conf/pf-release' ) ) );
    die unless $release =~ m/.*?(\d+(\.\d+){2}(-\d+)?)$/;
    return $1;
}

sub get_release_rev {
    die unless $PF_RELEASE_FULL =~ /^(\d+\.\d+)/;
    return $1;
}

sub get_base {
    my $base = read_file( $COMMIT_ID_FILE );
    if ($base) {
        chomp($base);
    }
    return $base;
}

sub get_head {
    my $url           = "$BASE_GITHUB_URL/branches/maintenance/$PF_RELEASE";
    my $response_body = get_url($url);
    my $data          = decode_json($response_body);
    return $data->{commit}->{sha};
}

sub get_patch_data {
    my ( $base, $head ) = @_;
    my $url           = "$BASE_GITHUB_URL/compare/${base}...${head}";
    my $response_body = get_url($url);
    my $data          = decode_json($response_body);
    return $data;
}

sub make_patch_filename {
    my ( $base, $head ) = @_;
    return catfile( $PATCHES_DIR, "${base}-${head}.diff" );
}

sub save_patch {
    my ( $data, $base, $head ) = @_;
    my $diff = get_url( $data->{diff_url} );
    write_file( make_patch_filename( $base, $head ), $diff );
}

sub apply_patch {
    my ( $data, $base, $head ) = @_;
    my $file = make_patch_filename( $base, $head );
    chdir $PF_DIR or die "cannot change directory $PF_DIR\n";
    system "$PATCH_BIN -b -p1 < $file";
    write_file( $COMMIT_ID_FILE, $head );
}

sub get_url {
    my ($url) = @_;
    my $request  = HTTP::Request->new( GET => $url ), my $response_body;
    my $ua       = LWP::UserAgent->new;
    $ua->show_progress(1);
    $ua->env_proxy;
    my $response = $ua->request($request);
    if ( $response->is_success ) {
        $response_body = $response->content;
    } else {
        die $response->status_line . "\n";
    }
    return $response_body;
}

sub patch_bin_exists {
     -x $PATCH_BIN
}

sub show_patch {
    my ($data) = @_;
    print "\nThe following are going to be patched\n";
    foreach my $file ( @{ $data->{files} } ) {
        print "  ", $file->{filename}, "\n";
    }
}

sub accept_patch {
    print "\nContinue y/n [y]: ";
    chomp(my $yes_no = <STDIN>);
    if ($yes_no =~ /n/) {
        exit;
    }
}

sub print_dot {
    print ".";
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

