use CPAN::FindDependencies;
my @dependencies = CPAN::FindDependencies::finddeps("$ARGV[0]");
foreach my $dep (@dependencies) {
    print '  ' x $dep->depth();
    print $dep->name().' ('.$dep->distribution().")\n";
}
