package pf::factory::condition::profile;
=head1 NAME

pf::factory::condition::profile add documentation

=cut

=head1 DESCRIPTION

pf::factory::condition::profile

=cut

use strict;
use warnings;
use Module::Pluggable search_path => 'pf::condition::profile', sub_name => '_modules' , require => 1;
our $DEFAULT_TYPE = 'ssid';
our $PROFILE_FILTER_REGEX = qr/^(([^:]|::)+?):(.*)$/;
use List::MoreUtils qw(any);


our @MODULES;
sub factory_for {'pf::condition::profile'};

my $DEFAULT_CONNECTION_TYPE = 'ssid';
my %PROFILE_FILTER_TYPE_TO_CONNECTION_TYPE = (

);

sub modules {
    unless(@MODULES) {
        @MODULES = __PACKAGE__->_modules;
    }
    return @MODULES;
}

sub instantiate {
    my ($class, @args) = @_;
    my $object;
    my ($type,$data) = $class->getData(@args);
    if ($data) {
        my $subclass = $class->getModuleName($type);
        $object = $subclass->new($data);
    }
    return $object;
}

sub getModuleName {
    my ($class, $type) = @_;
    my $mainClass = $class->factory_for;
    die "type is not defined" unless defined $type;
    my $subclass = "${mainClass}::${type}";
    die "$type is not a valid type" unless any {$_ eq $subclass} __PACKAGE__->modules;
    $subclass;
}

sub getData {
    my ($class, $filter) = @_;
    my ($type, $value);
    #Split parse the filter by type and value
    if ($filter =~ $PROFILE_FILTER_REGEX ) {
        $type  = $1;
        $value = $3;
    } else {
        #If there is no type defined to support older filters (3.5.0)
        $type  = $DEFAULT_TYPE;
        $value = $filter;
    }
    return $type, { value => $value};
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

1;
