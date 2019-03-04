package pf::Role::CHI::Driver::ComputeWithUndef;

=head1 NAME

pf::Role::CHI::Driver::ComputeWithUndef

=cut

=head1 DESCRIPTION

Adds a method that caches undef results in compute

=cut

use strict;
use warnings;
use Moo::Role;
use pfconfig::util qw($undef_element);

sub compute_with_undef {
    my ($self, $key, $on_miss, $options) = @_;
    my $return = $self->get($key);
    if(defined($return) && ref($return) eq "pfconfig::undef_element"){
        return undef;
    }
    elsif(defined($return)){
        return $return;
    }

    my $result = $on_miss->();
    if(defined($result)){
        $self->set($key,$result,$options);
    }
    else {
        $self->set($key, $undef_element,$options);
    }

    return $result;
}


=head1 AUTHOR

Inverse inc. <info@inverse.ca>

=head1 COPYRIGHT

Copyright (C) 2005-2019 Inverse inc.

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

