package pf::Moo::Util::Gen;
=head1 NAME

pf::Moo::Util::Gen add documentation

=cut

=head1 DESCRIPTION

pf::Moo::Util::Gen

=cut

use strict;
use warnings;
package pf::Moo::Util::Gen;

use Symbol();
use Module::Loaded();
use overload;

our $count = 0;

sub new_package { __PACKAGE__ . "::Dummy" . $count++};

sub new_class {
    my ($code,$data) = @_;
    my $package = new_package();
    $package->overload::OVERLOAD('&{}' => sub {${$_[0]}}, fallback => 1 );
    my $data_glob  = Symbol::qualify_to_ref("data",$package);
    *$data_glob = sub { $data };
    my $isa_glob  = Symbol::qualify_to_ref("ISA",$package);
    *$isa_glob = [qw(pf::Moo::Util::Gen::Dummy)];
    my $new_obj = bless \$code,$package;
    return $new_obj;
};

package pf::Moo::Util::Gen::Dummy;

sub DESTROY { Symbol::delete_package(ref($_[0])) }


=head1 AUTHOR

Inverse inc. <info@inverse.ca>

Minor parts of this file may have been contributed. See CREDITS.

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

