package pf::factory::pfcron::task;

=head1 NAME

pf::factory::pfcron::task -

=cut

=head1 DESCRIPTION

pf::factory::pfcron::task

=cut

use strict;
use warnings;
use List::MoreUtils qw(any);
use Module::Pluggable
  search_path => 'pf::pfcron::task',
  sub_name    => 'modules',
  inner       => 0,
  require     => 1;

use pf::config::pfcron qw(%ConfigCron);

sub factory_for { 'pf::pfcron::task' }

our @MODULES = __PACKAGE__->modules;

our %TYPES = map { /^pf::pfcron::task::(.*)$/ ; $1 => 1 } @MODULES;

=head2 new

Will create a new pf::pfcron::task sub class  based off the name of the task
If no task is found the return undef

=cut

sub new {
    my ($class, $name, $additional) = @_;
    if (!exists $TYPES{$name}) {
        return undef;
    }
    my $object;
    my $data = $ConfigCron{$name};
    if ($data) {
        %$data = (%$data, %{ $additional // {}});
        $data->{id} = $name;
        my $subclass = $class->getModuleName($name,$data);
        $object = $subclass->new($data);
    }
    return $object;
}


=head2 getModuleName

Get the sub module pf::pfcron::task base off it's configuration

=cut

sub getModuleName {
    my ($class,$name,$data) = @_;
    my $mainClass = $class->factory_for;
    my $type = $data->{type};
    my $subclass = "${mainClass}::${type}";
    die "type is not defined for $name" unless defined $type;
    die "$type is not a valid type" unless any { $_ eq $subclass  } @MODULES;
    $subclass;
}
 
=head1 AUTHOR

Inverse inc. <info@inverse.ca>

=head1 COPYRIGHT

Copyright (C) 2005-2024 Inverse inc.

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
