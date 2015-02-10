package pf::profile_list;

=head1 NAME

pf::profile_list add documentation

=cut

=head1 DESCRIPTION

pf::profile_list

=cut

use strict;
use warnings;
use pf::db;
use pf::log;

use constant PROFILE_LIST => 'profile_list';

BEGIN {
    use Exporter ();
    our (@ISA, @EXPORT);
    @ISA    = qw(Exporter);
    @EXPORT = qw(profile_list_total);
}

sub profile_list_total {
    my $source = shift,
    my @list = (
        {id => '1', name => 'Staff'},
        {id => '2', name => 'Human Resources'},
        {id => '3', name => 'Comptability'},
        {id => '4', name => 'Direction'},
    );
    return \@list; 
}
1;
