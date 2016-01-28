#!/usr/bin/perl

use strict;
use warnings;
use Getopt::Long;

my %options;
GetOptions (
  \%options,
  "h!",
  "base=s",
  "path=s",
  "desc=s",
) || die("Invalid options");

my $module = $options{path};
my $quoted_base = quotemeta($options{base});
$module =~ s/$quoted_base//g;
$module =~ s/^\///g;
$module =~ s/\.pm$//g;
$module =~ s/\//::/g;


use Template;

our $TT_OPTIONS = {
    ABSOLUTE => 1, 
};
our $template = Template->new($TT_OPTIONS);

our $vars = {
    module => $module,
    description => $options{desc},
};

$template->process("/usr/local/pf/addons/dev-helpers/module.tt", $vars, $options{path}) || die("Can't generate module : ".$template->error);

