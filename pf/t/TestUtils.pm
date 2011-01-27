package TestUtils;

=head1 NAME

TestUtils

=head1 DESCRIPTION

Various utilities to reduce code duplication in testing.

=cut

BEGIN {
    use Exporter ();
    our ( @ISA, @EXPORT );
    @ISA = qw(Exporter);
    @EXPORT_OK = qw(
        @cli_tests @compile_tests @dao_tests @integration_tests @quality_tests @unit_tests 
    );
}

# Tests are categorized here
our @cli_tests = qw(
    pfcmd.t
);

our @compile_tests = qw(
    binaries.t
    pf.t 
    php.t
);

our @dao_tests = qw(
    dao/person.t
);

our @integration_tests = qw(
    integration.t
);

our @quality_tests= qw(
    coding-style.t
    critic.t
    pod.t
    podCoverage.t
);

our @unit_tests = qw(
    config.t
    data.t
    floatingdevice.t
    graph.t
    hardware-snmp-objects.t
    import.t
    network-devices/cisco.t
    node.t
    nodecategory.t
    person.t 
    pfsetvlan.t
    radius.t
    report.t
    services.t
    SNMP.t 
    SwitchFactory.t
    util.t
    vlan.t
);


1;
