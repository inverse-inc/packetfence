package pf::MooX::AccessorAttribute;
=head1 NAME

pf::Moo::Role::AccessorAttribute add documentation

=cut

=head1 DESCRIPTION

pf::Moo::Role::AccessorAttribute

=cut

use strictures 1;

require Moo;
require Moo::Role;

our %INJECTED_IN;
our %OVERRIDEN;

require pf::Moo::Role::AccessorAttribute;

sub import {
    my $class = shift;
    my $target = caller;
    if ($Moo::Role::INFO{$target}) {
        # We are loaded from a Moo::Role
        if (! $OVERRIDEN{$target} ) {
            # We don't know yet in which class the role will be consumed, so we
            # have to work around that, and defer the injection

           my $old_accessor_maker = Moo->can('_accessor_maker_for');
            #
           my $new_accessor_maker_for = sub {
                my ($class, $role_target) = @_;
                my $maker = $old_accessor_maker->(@_);
                defined $maker
                  or return;
                $role_target->can('__accessor_attribute_mode')
                  && $role_target->__accessor_attribute_mode
                  && ! $INJECTED_IN{$role_target}
                    or return $maker;
                Moo::Role->apply_roles_to_object(
                    $maker,
                    'pf::Moo::Role::AccessorAttribute',
                );
                $INJECTED_IN{$role_target} = 1;
                return $maker;
            };

           my $old_constructor_maker_for = Moo->can('_constructor_maker_for');
            #
           my $new_constructor_maker_for = sub {
                my ($class, $role_target) = @_;
                my $maker = $old_constructor_maker_for->(@_);
                defined $maker
                  or return;
                $role_target->can('__accessor_attribute_mode')
                  && $role_target->__accessor_attribute_mode
                  && ! $INJECTED_IN{$role_target}
                    or return $maker;
                Moo::Role->apply_roles_to_object(
                    $maker,
                    'pf::Moo::Role::AccessorAttribute',
                );
                $INJECTED_IN{$role_target} = 1;
                return $maker;
            };
            no strict 'refs';
            no warnings 'redefine';
            *{"${target}::__accessor_attribute_mode"} = sub { 1 };
            *Moo::_accessor_maker_for = $new_accessor_maker_for;
            $OVERRIDEN{$target} = 1
        }
    } elsif ($Moo::MAKERS{$target}) {
        # We are loaded from a Moo class
        if ( !$INJECTED_IN{$target} ) {
            Moo::Role->apply_roles_to_object(
              Moo->_accessor_maker_for($target),
              'pf::Moo::Role::AccessorAttribute',
            );
            Moo::Role->apply_roles_to_object(
              Moo->_constructor_maker_for($target),
              'pf::Moo::Role::AccessorAttribute',
            );
            $INJECTED_IN{$target} = 1;
        }
    } else {
        die __PACKAGE__ . " can only be used in Moo classes or Moo roles.";
    }

}


1;

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

