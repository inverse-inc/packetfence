package pf::config::builder::filter_engine::radius;

=head1 NAME

pf::config::builder::filter_engine::radius -

=head1 DESCRIPTION

pf::config::builder::filter_engine::radius

=cut

use strict;
use warnings;
use base qw(pf::config::builder::filter_engine);
use pf::mini_template;
use pf::util::radius_dictionary qw($RADIUS_DICTIONARY);

sub updateAnswers {
    my ($self, $buildData, $id, $entry, $answers) = @_;
    my ($errors, $attrs) = make_radius_attribute_set($answers);
    return $attrs;
}

sub make_radius_attribute_set {
    my ($radius_attr_set) = @_;
    my @errors;
    my @set = map { make_radius_attribute(\@errors, $_)  } @$radius_attr_set;
    return (@errors ? \@errors : undef ), \@set;
}

=head2 make_radius_attribute

make_radius_attribute

=cut

sub make_radius_attribute {
    my ($errors, $ra) = @_;
    my ($n, $tmpl_text) = split /\s*=\s*/, $ra, 2;
    if (!defined $tmpl_text) {
        push @{$errors}, { name => 'unknown', text => $ra, message => "is not a valid radius attribute" };
        return;
    }

    my $attr = {
        name => $n,
    };

    my $tmpl = eval { pf::mini_template->new($tmpl_text) };
    if ($@) {
        push @{$errors}, { %$attr, message => $@, text => $ra };
        return;
    }

    $attr->{tmpl} = $tmpl;
    return $attr;
}

=head1 AUTHOR

Inverse inc. <info@inverse.ca>

=head1 COPYRIGHT

Copyright (C) 2005-2024 Inverse inc.

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
