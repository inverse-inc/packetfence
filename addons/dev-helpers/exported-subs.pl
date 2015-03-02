#!/usr/bin/perl

use lib '/usr/local/pf/lib';

my $module = $ARGV[0];
my $search_path = $ARGV[1] || "lib/";

eval('use '.$module);
my @exported = eval('@'.$module.'::EXPORT');

my $regex = '(';
foreach my $variable (@exported){
  unless($variable =~ s/^([\$@%]{1})//){
    print "$variable \n";
    $regex .= "$variable|";
  }
}
chop $regex;
$regex .= ")";

print "regex : $regex \n";

print "-----------------------------------\n";

print `egrep -r "$regex" $search_path`;
