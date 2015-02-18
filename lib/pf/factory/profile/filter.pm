package pf::factory::profile::filter;

=head1 NAME

pf::factory::profile::filter - factory for Profile filters

=cut

=head1 DESCRIPTION

pf::factory::profile::filter

Loads and instantiates profile filters

=cut

use strict;
use warnings;
use Module::Pluggable
  search_path => [qw(pf::profile::filter)],

# Don't explicilty load pf::profile::filter::key
# Since it will not be explictly used

  except => [qw(pf::profile::filter::key pf::profile::filter::key_couple pf::profile::filter::all)],
  'require' => 1,
  sub_name    => 'modules';
use List::MoreUtils qw(any);

our @MODULES = __PACKAGE__->modules;

our $DEFAULT_TYPE = 'ssid';


#Regex of the filter to split the type and value of filter
our $FILTER_REGEX = qr/^(([^:]|::)+?):(.*)$/;

sub factory_for {'pf::profile::filter'}

sub instantiate {
    my ($class, @args) = @_;
    my $object;
    my $data = $class->getData(@args);
    if ($data) {
        my $subclass = $class->getModuleName($data);
        $object = $subclass->new($data);
    }
    return $object;
}

sub getModuleName {
    my ($class, $data) = @_;
    my $mainClass = $class->factory_for;
    my $type      = $data->{type};
    die "type is not defined" unless defined $type;
    my $subclass = "${mainClass}::${type}";
    die "$type is not a valid type" unless any {$_ eq $subclass} @MODULES;
    $subclass;
}

sub getData {
    my ($class, $profile, $filter) = @_;
    my ($type, $value);
    #Split parse the filter by type and value
    if ($filter =~ $FILTER_REGEX ) {
        $type  = $1;
        $value = $3;
    } else {
        #If there is no type defined to support older filters (3.5.0)
        $type  = $DEFAULT_TYPE;
        $value = $filter;
    }
    return {type => $type, value => $value, profile => $profile};
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

