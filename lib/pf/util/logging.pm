package pf::util::logging;

our $VERSION = 1.000000;

use Exporter 'import';

our @EXPORT_OK = qw(called);
sub called {
    return (caller(1))[3];
}

1;
