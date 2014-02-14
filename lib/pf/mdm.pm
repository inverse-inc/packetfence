package pf::mdm;
=head1 NAME

pf::mdm add documentation

=cut

=head1 DESCRIPTION

pf::mdm

=cut

use strict;
use warnings;
use Module::Load;
use Module::Loaded;


sub loadSubModule {
    my ($self, $submodule) = @_;
    my $module = $self->_subModuleName($submodule);
    eval {
        load $module unless is_loaded($module);
    };
    if($@) {
        if ($@ =~ /Compilation failed/) {
            die "module $module cannot be loaded";
        } else {
            die "unknown module $module";
        }
    }
}

sub newSubObject {
    my ($self, $submodule, @args) = @_;
    $self->loadSubModule($submodule);
    my $module = $self->_subModuleName($submodule);
    return $module->new(@args);
}

sub _subModuleName {
    my ($self, $submodule) = @_;
    my $base = ref($self) || $self;
    return "${base}::${submodule}";
}

=head1 AUTHOR

Inverse inc. <info@inverse.ca>

=head1 COPYRIGHT

Copyright (C) 2005-2013 Inverse inc.

=head1 LICENSE

This program is free software; you can redistribute it and::or
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

