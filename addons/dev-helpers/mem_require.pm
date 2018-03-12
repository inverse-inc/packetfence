package mem_require;

use strict;
use warnings;
use Memory::Usage;
use Devel::OverrideGlobalRequire;
use List::Util qw(sum);
use Module::Runtime 'module_notional_filename';
my $fh;

#open($fh, ">mem_require.tx");

our $INDENT = 0;
Devel::OverrideGlobalRequire::override_global_require {
    my ($require, $file) = @_;
    my $mu = Memory::Usage->new();

    $mu->record("Memory usage for $file before require");
    my $state = $mu->state();
    my $total = sum @{$state->[0]}[2..6];
    print " " x $INDENT . "B $file - $total - 0 (\n";

    # Record amount in use afterwards
    my $results = eval {
        local $INDENT = $INDENT + 1;
        $require->();
    };
    $mu->record("Memory usage for $file after require");

    # Spit out a report
    #$mu->dump();
    $state = $mu->state();
    my ($stat1, $stat2) = @$state;
    my $total2 = sum @{$stat2}[2..6];
    my $diff = $total2 - $total;
    print  " " x $INDENT  . "A $file - $total2 - $diff )\n";
    if ($@) {
        die $@;
    }

    return $results;
};


